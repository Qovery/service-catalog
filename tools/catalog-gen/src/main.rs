use anyhow::{Context, Result};
use chrono::Utc;
use clap::{Parser, Subcommand};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::process::Command;

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

#[derive(Parser)]
#[command(name = "catalog-gen")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate catalog.json from QBM manifests and git tags
    Generate(GenerateArgs),
    /// Validate all QBM manifests and TF variable alignment; exits non-zero on any error
    Validate(RootArg),
    /// Print Terraform blueprint paths as a JSON array (used for CI matrix discovery)
    ListTerraform(RootArg),
    /// Verify each changed blueprint bumped its metadata.version vs the base ref
    CheckVersionBump(CheckVersionBumpArgs),
    /// Create git tags for blueprint versions, push them, and create GitHub releases
    AutoTag(AutoTagArgs),
    /// Tag changed blueprints with a prerelease suffix so a PR branch can be deployed before merge
    Prerelease(PrereleaseArgs),
}

#[derive(Parser)]
struct GenerateArgs {
    #[arg(long, default_value = ".")]
    root: PathBuf,
    #[arg(long, short)]
    output: PathBuf,
}

#[derive(Parser)]
struct RootArg {
    #[arg(long, default_value = ".")]
    root: PathBuf,
}

#[derive(Parser)]
struct CheckVersionBumpArgs {
    #[arg(long, default_value = ".")]
    root: PathBuf,
    /// Base ref to diff against (e.g. origin/main)
    #[arg(long, default_value = "origin/main")]
    base_ref: String,
}

#[derive(Parser)]
struct AutoTagArgs {
    #[arg(long, default_value = ".")]
    root: PathBuf,
    /// Remote to push tags to
    #[arg(long, default_value = "origin")]
    remote: String,
    /// Skip `git push --tags` (for local dry-run testing)
    #[arg(long)]
    no_push: bool,
    /// Skip `gh release create` (for local dry-run testing)
    #[arg(long)]
    no_release: bool,
}

#[derive(Parser)]
struct PrereleaseArgs {
    #[arg(long, default_value = ".")]
    root: PathBuf,
    /// Base ref to diff against; only blueprints changed since this ref are tagged
    #[arg(long, default_value = "origin/main")]
    base_ref: String,
    /// Prerelease suffix appended to metadata.version. Must identify the commit so the tag never
    /// needs a force update, and must end in `-rc` so the repository tag ruleset's
    /// `refs/tags/**/*-rc` exclusion matches it.
    /// e.g. "pr45.a1b2c3d-rc" -> AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc
    #[arg(long)]
    suffix: String,
    /// Remote to push tags to
    #[arg(long, default_value = "origin")]
    remote: String,
    /// Create the tags locally but do not push them. They stay in the repo — use --dry-run to
    /// inspect the output without writing any refs.
    #[arg(long)]
    no_push: bool,
    /// Compute and print the tags and payloads without creating or pushing any ref
    #[arg(long)]
    dry_run: bool,
}

// ---------------------------------------------------------------------------
// QBM types for catalog generation
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct Qbm {
    kind: Option<String>,
    metadata: QbmMetadata,
    spec: Option<QbmSpec>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct QbmMetadata {
    name: String,
    version: String,
    description: Option<String>,
    icon: Option<String>,
    service_family: Option<String>,
    categories: Option<Vec<String>>,
}

#[derive(Deserialize)]
struct QbmSpec {
    engine: Option<QbmEngineRef>,
}

#[derive(Deserialize)]
struct QbmEngineRef {
    provider: Option<String>,
}

// ---------------------------------------------------------------------------
// QBM types for validation
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct ValidateQbm {
    #[serde(rename = "apiVersion")]
    api_version: Option<String>,
    kind: Option<String>,
    metadata: Option<ValidateMeta>,
    spec: Option<ValidateSpec>,
}

#[derive(Deserialize)]
struct ValidateMeta {
    name: Option<String>,
    version: Option<String>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct ValidateSpec {
    engine: Option<ValidateEngine>,
    variables: Vec<VarDecl>,
    #[serde(rename = "contextVariables")]
    context_variables: Vec<VarDecl>,
    stages: Option<serde_yaml::Value>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct ValidateEngine {
    #[serde(rename = "type")]
    type_: Option<String>,
    provider: Option<String>,
    chart: Option<serde_yaml::Value>,
    /// Nested per-engine block carrying the terraform binary version. Required when type=terraform.
    terraform: Option<ValidateEngineVersion>,
    /// Nested per-engine block carrying the opentofu binary version. Required when type=opentofu.
    opentofu: Option<ValidateEngineVersion>,
    credentials: Option<ValidateCredentials>,
    backend: Option<ValidateBackend>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct ValidateEngineVersion {
    version: Option<String>,
    #[serde(rename = "allowedValues")]
    allowed_values: Option<Vec<String>>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct ValidateCredentials {
    default: Option<String>,
    #[serde(rename = "allowedValues")]
    allowed_values: Option<Vec<String>>,
    overridable: Option<bool>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct ValidateBackend {
    default: Option<String>,
    #[serde(rename = "allowedValues")]
    allowed_values: Option<Vec<String>>,
    overridable: Option<bool>,
    /// Required when `default = user_provided`. Engine forwards type+config to the Qovery
    /// terraform provider for backend.tf generation.
    user_provided: Option<ValidateUserProvidedBackend>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct ValidateUserProvidedBackend {
    #[serde(rename = "type")]
    backend_type: Option<String>,
    config: Option<std::collections::HashMap<String, String>>,
}

const CREDENTIAL_MODES: &[&str] = &["cluster", "env"];
const BACKEND_MODES: &[&str] = &["qovery", "user_provided"];
// Top-level provider dirs the platform can parse (q-core BlueprintIacProvider + HELM).
// Extending this list is a platform change — ship q-core/console support first (see AGENTS.md).
const PROVIDERS: &[&str] = &["AWS", "SCW", "GCP", "AZURE", "EXTERNAL", "HELM"];

#[derive(Deserialize)]
struct VarDecl {
    name: String,
    /// Only set on `contextVariables` entries: where the engine takes the value from.
    source: Option<String>,
    #[serde(rename = "type")]
    type_: Option<String>,
    default: Option<String>,
    #[serde(rename = "allowedValues")]
    allowed_values: Option<Vec<String>>,
    min: Option<f64>,
    max: Option<f64>,
    // String-only constraints surfaced to the console for client-side validation.
    pattern: Option<String>,
    #[serde(rename = "minLength")]
    min_length: Option<u64>,
    #[serde(rename = "maxLength")]
    max_length: Option<u64>,
    // Defaults to false when omitted. Authors must mark sensitive variables explicitly so the
    // console renders them as secret inputs.
    sensitive: Option<bool>,
}

// ---------------------------------------------------------------------------
// catalog.json output types
// ---------------------------------------------------------------------------

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Catalog {
    version: String,
    generated_at: String,
    blueprints: Vec<CatalogBlueprint>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CatalogBlueprint {
    name: String,
    kind: String,
    description: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    icon: Option<String>,
    categories: Vec<String>,
    provider: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    service_family: Option<String>,
    major_versions: Vec<MajorVersion>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MajorVersion {
    service_version: String,
    latest_tag: Option<String>,
}

// ---------------------------------------------------------------------------
// Skip directories
// ---------------------------------------------------------------------------

const SKIP_DIRS: &[&str] = &[
    "tools", "scripts", ".github", ".git", ".idea", "stacks", "diagrams",
];

// ---------------------------------------------------------------------------
// Blueprint discovery
// ---------------------------------------------------------------------------

struct VersionDir {
    provider: String,
    service: String,
    version: String,
    full_path: String,
}

fn discover_version_dirs(root: &Path) -> Result<Vec<VersionDir>> {
    let mut dirs = Vec::new();

    let entries = std::fs::read_dir(root).context("Failed to read repo root")?;
    for entry in entries {
        let entry = entry?;
        let provider_name = entry.file_name().to_string_lossy().to_string();

        if provider_name.starts_with('.') || SKIP_DIRS.contains(&provider_name.as_str()) {
            continue;
        }
        if !entry.file_type()?.is_dir() {
            continue;
        }

        let provider_path = entry.path();
        let service_entries =
            std::fs::read_dir(&provider_path).context("Failed to read provider dir")?;

        for service_entry in service_entries {
            let service_entry = service_entry?;
            if !service_entry.file_type()?.is_dir() {
                continue;
            }

            let service_name = service_entry.file_name().to_string_lossy().to_string();
            let service_path = service_entry.path();
            let version_entries =
                std::fs::read_dir(&service_path).context("Failed to read service dir")?;

            for version_entry in version_entries {
                let version_entry = version_entry?;
                if !version_entry.file_type()?.is_dir() {
                    continue;
                }

                let version_name = version_entry.file_name().to_string_lossy().to_string();
                let qbm_path = version_entry.path().join("qbm.yml");
                if qbm_path.exists() {
                    dirs.push(VersionDir {
                        provider: provider_name.clone(),
                        service: service_name.clone(),
                        version: version_name.clone(),
                        full_path: format!("{}/{}/{}", provider_name, service_name, version_name),
                    });
                }
            }
        }
    }

    dirs.sort_by(|a, b| a.full_path.cmp(&b.full_path));
    Ok(dirs)
}

// ---------------------------------------------------------------------------
// Catalog generation
// ---------------------------------------------------------------------------

fn generate_catalog(root: &Path) -> Result<Catalog> {
    let version_dirs = discover_version_dirs(root)?;

    let mut groups: BTreeMap<String, Vec<VersionDir>> = BTreeMap::new();
    for vd in version_dirs {
        let key = format!("{}/{}", vd.provider, vd.service);
        groups.entry(key).or_default().push(vd);
    }

    let mut catalog_blueprints: Vec<CatalogBlueprint> = Vec::new();

    for (_service_path, version_dirs) in &groups {
        let mut major_versions: Vec<MajorVersion> = Vec::new();
        let mut top_qbm: Option<Qbm> = None;

        for vd in version_dirs {
            // metadata.version in qbm.yml is the source of truth for the tag that auto-tag will
            // create on merge. Using git tag history would lag by one merge: a PR that bumps
            // metadata.version would otherwise still show the previous tag.
            let qbm_from_disk: Option<Qbm> =
                std::fs::read_to_string(root.join(&vd.full_path).join("qbm.yml"))
                    .ok()
                    .and_then(|c| serde_yaml::from_str(&c).ok());
            let latest_tag = qbm_from_disk
                .as_ref()
                .map(|q| format!("{}/{}", vd.full_path, q.metadata.version));

            if top_qbm.is_none() {
                let qbm = qbm_from_disk;
                top_qbm = qbm;
            }

            major_versions.push(MajorVersion {
                service_version: vd.version.clone(),
                latest_tag,
            });
        }

        let qbm = match top_qbm {
            Some(q) => q,
            None => {
                let first_vd = &version_dirs[0];
                let qbm_path = root.join(&first_vd.full_path).join("qbm.yml");
                let content = std::fs::read_to_string(&qbm_path)
                    .with_context(|| format!("Failed to read {}", qbm_path.display()))?;
                serde_yaml::from_str(&content).context("Failed to parse qbm.yml")?
            }
        };

        let provider = qbm
            .spec
            .as_ref()
            .and_then(|s| s.engine.as_ref())
            .and_then(|e| e.provider.clone())
            .unwrap_or_else(|| version_dirs[0].provider.clone());
        catalog_blueprints.push(CatalogBlueprint {
            name: qbm.metadata.name,
            kind: qbm.kind.unwrap_or_else(|| "ServiceBlueprint".to_string()),
            description: qbm.metadata.description.unwrap_or_default(),
            icon: qbm.metadata.icon,
            categories: qbm.metadata.categories.unwrap_or_default(),
            provider,
            service_family: qbm.metadata.service_family,
            major_versions,
        });
    }

    Ok(Catalog {
        version: "1".to_string(),
        generated_at: Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string(),
        blueprints: catalog_blueprints,
    })
}

// ---------------------------------------------------------------------------
// Variable constraint validation
// ---------------------------------------------------------------------------

// Variable names that look like they should be sensitive. Catches catalog authors who forget
// to set `sensitive: true` (especially on Helm blueprints, which have no TF to cross-check).
fn looks_sensitive(name: &str) -> bool {
    let re = Regex::new(r"(?i)(^|_)(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key)($|_)").unwrap();
    re.is_match(name)
}

// Validates that an enum-like field (credentials.default, backend.default) is within the platform's
// supported universe, and that authoring constraints hold:
//   - any value in allowedValues must be in the universe;
//   - default must be in the universe;
//   - default must be in allowedValues when allowedValues is set.
fn validate_allowed_values_subset(
    path: &str,
    field: &str,
    default: Option<&str>,
    allowed: Option<&Vec<String>>,
    universe: &[&str],
    errors: &mut Vec<String>,
) {
    if let Some(av) = allowed {
        for v in av {
            if !universe.contains(&v.as_str()) {
                errors.push(format!(
                    "{}: spec.engine.{}.allowedValues contains '{}' (must be one of {:?})",
                    path, field, v, universe
                ));
            }
        }
        if let Some(d) = default {
            if !av.iter().any(|a| a == d) {
                errors.push(format!(
                    "{}: spec.engine.{}.default '{}' not in allowedValues {:?}",
                    path, field, d, av
                ));
            }
        }
    }
    if let Some(d) = default {
        if !universe.contains(&d) {
            errors.push(format!(
                "{}: spec.engine.{}.default '{}' must be one of {:?}",
                path, field, d, universe
            ));
        }
    }
}

fn validate_sensitive_naming(path: &str, var: &VarDecl, errors: &mut Vec<String>) {
    if looks_sensitive(&var.name) && var.sensitive != Some(true) {
        errors.push(format!(
            "{}: '{}' name looks sensitive — add sensitive: true to qbm.yml (or rename the variable)",
            path, var.name
        ));
    }
}

fn validate_var_constraints(path: &str, var: &VarDecl, errors: &mut Vec<String>) {
    if let Some(av) = &var.allowed_values {
        if let Some(default) = &var.default {
            if !av.contains(default) {
                errors.push(format!(
                    "{}: '{}' default '{}' is not in allowedValues",
                    path, var.name, default
                ));
            }
        }
        if var.type_.as_deref() == Some("bool") {
            errors.push(format!(
                "{}: '{}' allowedValues is not meaningful for bool type",
                path, var.name
            ));
        }
    }

    if var.min.is_some() || var.max.is_some() {
        if var.type_.as_deref() != Some("number") {
            errors.push(format!(
                "{}: '{}' min/max can only be used with type: number",
                path, var.name
            ));
        }
        if let (Some(min), Some(max)) = (var.min, var.max) {
            if min > max {
                errors.push(format!(
                    "{}: '{}' min ({}) is greater than max ({})",
                    path, var.name, min, max
                ));
            }
        }
    }

    // String-only constraints. A null type is also treated as string by q-core, so we accept them
    // there too rather than only when the author wrote `type: string` explicitly.
    let is_string_typed = matches!(var.type_.as_deref(), None | Some("string"));
    if (var.pattern.is_some() || var.min_length.is_some() || var.max_length.is_some())
        && !is_string_typed
    {
        errors.push(format!(
            "{}: '{}' pattern/minLength/maxLength can only be used with type: string",
            path, var.name
        ));
    }
    if let Some(pattern) = &var.pattern {
        if Regex::new(pattern).is_err() {
            errors.push(format!(
                "{}: '{}' pattern '{}' is not a valid regular expression",
                path, var.name, pattern
            ));
        }
    }
    if let (Some(min), Some(max)) = (var.min_length, var.max_length) {
        if min > max {
            errors.push(format!(
                "{}: '{}' minLength ({}) is greater than maxLength ({})",
                path, var.name, min, max
            ));
        }
    }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

// Injected into every Terraform blueprint whether or not the manifest asks: plumbing for the
// cluster-network lookups rather than context an author selects. Undeclared, terraform prints
// "Value for undeclared variable" into plan output the update preview shows users verbatim.
const ALWAYS_INJECTED_VARIABLES: [&str; 1] = ["qovery_user_provided_network"];

/// Terraform variables a `contextVariables[].source` fills, given the entry's declared name.
/// Mirrors the engine's `inject_context_variables`; anything else is a typo that would leave the
/// variable silently unset, which is how `qovery_cluster_id` went missing for a whole release.
fn source_targets(source: &str, declared_name: &str) -> Option<Vec<String>> {
    match source {
        "cluster.region" | "cluster.name" => Some(vec![declared_name.to_string()]),
        // One entry, two variables: a module needing the cluster identity needs both forms.
        "cluster.id" => Some(vec![declared_name.to_string(), "qovery_cluster_long_id".to_string()]),
        _ => None,
    }
}

// Reads a `<<TAG` / `<<-TAG` opener at `i`, returning the tag, whether it was the indented
// (`<<-`) form, and the offset just past the opener line. Returns None when what follows `<<`
// is not an identifier.
fn heredoc_tag(b: &[char], i: usize) -> Option<(String, bool, usize)> {
    let mut j = i + 2;
    let indented = b.get(j) == Some(&'-');
    if indented {
        j += 1;
    }
    let start = j;
    while j < b.len() && (b[j].is_alphanumeric() || b[j] == '_') {
        j += 1;
    }
    if j == start {
        return None;
    }
    let tag: String = b[start..j].iter().collect();
    while j < b.len() && b[j] != '\n' {
        j += 1;
    }
    Some((tag, indented, (j + 1).min(b.len())))
}

// Blanks out `#`, `//` and `/* */` comments, keeping newlines so line structure survives. A `#`
// inside a quoted string is not a comment, so strings are tracked and copied through verbatim —
// which also keeps the `variable "name"` label itself intact. Heredoc bodies are copied verbatim
// too, since their contents are data and may legitimately contain comment markers.
fn strip_hcl_comments(tf: &str) -> String {
    let mut out = String::with_capacity(tf.len());
    let b: Vec<char> = tf.chars().collect();
    let (mut i, mut in_string) = (0, false);
    while i < b.len() {
        let c = b[i];
        if in_string {
            out.push(c);
            match c {
                '\\' if i + 1 < b.len() => {
                    out.push(b[i + 1]);
                    i += 2;
                    continue;
                }
                '"' => in_string = false,
                _ => {}
            }
            i += 1;
        } else if c == '"' {
            in_string = true;
            out.push(c);
            i += 1;
        } else if c == '#' || (c == '/' && b.get(i + 1) == Some(&'/')) {
            while i < b.len() && b[i] != '\n' {
                i += 1;
            }
        } else if c == '/' && b.get(i + 1) == Some(&'*') {
            i += 2;
            while i < b.len() && !(b[i] == '*' && b.get(i + 1) == Some(&'/')) {
                if b[i] == '\n' {
                    out.push('\n');
                }
                i += 1;
            }
            i += 2;
        } else if c == '<' && b.get(i + 1) == Some(&'<') && heredoc_tag(&b, i).is_some() {
            // A heredoc body is data, not HCL. Its contents may hold `#`, `//`, an unterminated
            // `/*`, a stray `}`, or even a literal `variable "x" {` — none of which are source
            // comments or declarations. Blank the body so nothing inside it is interpreted either
            // way, keeping the opener and the newlines.
            let (tag, indented, body_start) = heredoc_tag(&b, i).unwrap();
            out.extend(b[i..body_start].iter());
            i = body_start;
            while i < b.len() {
                let line_start = i;
                while i < b.len() && b[i] != '\n' {
                    i += 1;
                }
                let line: String = b[line_start..i].iter().collect();
                if i < b.len() {
                    out.push('\n');
                    i += 1;
                }
                // Only `<<-` allows the terminator to be indented. For a plain `<<`, an indented
                // tag is body text, and ending there would spill the rest of the heredoc into the
                // scan as if it were HCL. trim_end still tolerates a trailing CR.
                let terminated = if indented {
                    line.trim() == tag
                } else {
                    line.trim_end() == tag
                };
                if terminated {
                    break;
                }
            }
        } else {
            out.push(c);
            i += 1;
        }
    }
    out
}

// Captures each `variable "name" { ... }` block: group 1 is the name, group 2 is the body
// (until the next closing `}`). Assumes no nested braces inside variable blocks, which holds
// for the catalog's flat declarations. Comments are stripped first so a commented-out block is
// not read as a declaration — terraform would still reject the missing variable at apply.
fn parse_tf_variables(tf: &str) -> HashMap<String, bool> {
    let tf = strip_hcl_comments(tf);
    let re = Regex::new(r#"(?s)variable\s+"(\w+)"\s*\{([^}]*)\}"#).unwrap();
    let sensitive_re = Regex::new(r#"(?m)^\s*sensitive\s*=\s*true\b"#).unwrap();
    re.captures_iter(&tf)
        .map(|c| (c[1].to_string(), sensitive_re.is_match(&c[2])))
        .collect()
}

fn validate_blueprints(root: &Path) -> Result<()> {
    let version_dirs = discover_version_dirs(root)?;
    let mut errors: Vec<String> = Vec::new();

    let mut unknown_providers = std::collections::BTreeSet::new();
    for vd in &version_dirs {
        if !PROVIDERS.contains(&vd.provider.as_str()) && unknown_providers.insert(vd.provider.clone()) {
            errors.push(format!(
                "{}: unknown provider dir '{}' — allowed: {}",
                vd.full_path,
                vd.provider,
                PROVIDERS.join(", ")
            ));
        }
    }

    for vd in &version_dirs {
        let qbm_path = root.join(&vd.full_path).join("qbm.yml");
        let content = match std::fs::read_to_string(&qbm_path) {
            Ok(c) => c,
            Err(e) => {
                errors.push(format!("{}: cannot read qbm.yml: {}", vd.full_path, e));
                continue;
            }
        };

        let qbm: ValidateQbm = match serde_yaml::from_str(&content) {
            Ok(q) => q,
            Err(e) => {
                errors.push(format!("{}: invalid YAML: {}", vd.full_path, e));
                continue;
            }
        };

        if qbm.api_version.is_none() {
            errors.push(format!("{}: missing apiVersion", vd.full_path));
        }
        let kind = qbm.kind.as_deref().unwrap_or("ServiceBlueprint");
        if qbm.kind.is_none() {
            errors.push(format!("{}: missing kind", vd.full_path));
        }

        match &qbm.metadata {
            None => errors.push(format!("{}: missing metadata", vd.full_path)),
            Some(m) => {
                if m.name.is_none() {
                    errors.push(format!("{}: missing metadata.name", vd.full_path));
                }
                if m.version.is_none() {
                    errors.push(format!("{}: missing metadata.version", vd.full_path));
                }
            }
        }

        let spec = match &qbm.spec {
            None => {
                errors.push(format!("{}: missing spec", vd.full_path));
                continue;
            }
            Some(s) => s,
        };

        if kind == "StackBlueprint" {
            if spec.stages.is_none() {
                errors.push(format!(
                    "{}: spec.stages required for StackBlueprint",
                    vd.full_path
                ));
            }
        } else {
            let engine = spec.engine.as_ref();
            let engine_type = engine.and_then(|e| e.type_.as_deref());
            let engine_provider = engine.and_then(|e| e.provider.as_ref());
            let engine_chart = engine.and_then(|e| e.chart.as_ref());

            // The version block is named after the engine type. Pull the right one and surface
            // a clear error when the wrong block is used (e.g. terraform manifest with opentofu block).
            let (version_block, wrong_block) = match engine_type {
                Some("terraform") => (engine.and_then(|e| e.terraform.as_ref()), engine.and_then(|e| e.opentofu.as_ref()).map(|_| "opentofu")),
                Some("opentofu")  => (engine.and_then(|e| e.opentofu.as_ref()), engine.and_then(|e| e.terraform.as_ref()).map(|_| "terraform")),
                _                 => (None, None),
            };
            if let Some(name) = wrong_block {
                errors.push(format!(
                    "{}: spec.engine.{} block is set but engine.type is '{}'",
                    vd.full_path, name, engine_type.unwrap_or("")
                ));
            }

            let creds = engine.and_then(|e| e.credentials.as_ref());
            validate_allowed_values_subset(
                &vd.full_path,
                "credentials",
                creds.and_then(|c| c.default.as_deref()),
                creds.and_then(|c| c.allowed_values.as_ref()),
                CREDENTIAL_MODES,
                &mut errors,
            );
            let backend = engine.and_then(|e| e.backend.as_ref());
            validate_allowed_values_subset(
                &vd.full_path,
                "backend",
                backend.and_then(|b| b.default.as_deref()),
                backend.and_then(|b| b.allowed_values.as_ref()),
                BACKEND_MODES,
                &mut errors,
            );
            if backend.and_then(|b| b.default.as_deref()) == Some("user_provided")
                && backend.and_then(|b| b.user_provided.as_ref()).is_none()
            {
                errors.push(format!(
                    "{}: spec.engine.backend.user_provided is required when backend.default = user_provided",
                    vd.full_path,
                ));
            }
            if let Some(up) = backend.and_then(|b| b.user_provided.as_ref()) {
                if up.backend_type.as_deref().unwrap_or("").trim().is_empty() {
                    errors.push(format!(
                        "{}: spec.engine.backend.user_provided.type must be set (e.g. \"s3\", \"gcs\", \"azurerm\")",
                        vd.full_path,
                    ));
                }
            }

            // EXTERNAL blueprints have no cluster cloud credentials to reuse (see AGENTS.md).
            // Checked for every engine type: helm needs no credentials block, but if one is
            // present it must not point at cluster either.
            if vd.provider == "EXTERNAL" {
                let is_iac = matches!(engine_type, Some("terraform") | Some("opentofu"));
                let default_mode = creds.and_then(|c| c.default.as_deref());
                if is_iac && default_mode != Some("env") {
                    errors.push(format!(
                        "{}: EXTERNAL blueprints require spec.engine.credentials.default = env",
                        vd.full_path
                    ));
                } else if default_mode == Some("cluster") {
                    errors.push(format!(
                        "{}: EXTERNAL blueprints must not use 'cluster' in spec.engine.credentials.default",
                        vd.full_path
                    ));
                }
                if creds
                    .and_then(|c| c.allowed_values.as_ref())
                    .is_some_and(|values| values.iter().any(|mode| mode == "cluster"))
                {
                    errors.push(format!(
                        "{}: EXTERNAL blueprints must not allow 'cluster' in spec.engine.credentials.allowedValues",
                        vd.full_path
                    ));
                }
            }

            match engine_type {
                Some("terraform") | Some("opentofu") => {
                    match engine_provider {
                        None => errors.push(format!(
                            "{}: spec.engine.provider required when engine.type is terraform/opentofu",
                            vd.full_path
                        )),
                        // catalog.json takes provider from spec.engine.provider while the manifest
                        // fetch path is built from the directory — a mismatch 404s in the console.
                        Some(p) if p != &vd.provider => errors.push(format!(
                            "{}: spec.engine.provider '{}' does not match top-level directory '{}'",
                            vd.full_path, p, vd.provider
                        )),
                        Some(_) => {}
                    }
                    let version_label = engine_type.unwrap_or("terraform"); // "terraform" or "opentofu"
                    match version_block {
                        None => errors.push(format!(
                            "{}: spec.engine.{}.version required when engine.type is {} (e.g. \"1.9.7\")",
                            vd.full_path, version_label, version_label
                        )),
                        Some(vb) => {
                            let version = vb.version.as_deref().map(str::trim).filter(|s| !s.is_empty());
                            match version {
                                None => errors.push(format!(
                                    "{}: spec.engine.{}.version required when engine.type is {} (e.g. \"1.9.7\")",
                                    vd.full_path, version_label, version_label
                                )),
                                Some(v) => {
                                    if let Some(allowed) = vb.allowed_values.as_ref() {
                                        if !allowed.iter().any(|a| a == v) {
                                            errors.push(format!(
                                                "{}: spec.engine.{}.version '{}' not in allowedValues {:?}",
                                                vd.full_path, version_label, v, allowed
                                            ));
                                        }
                                    }
                                }
                            }
                        }
                    }
                    let vars_path = root.join(&vd.full_path).join("variables.tf");
                    match std::fs::read_to_string(&vars_path) {
                        Err(_) => {
                            errors.push(format!("{}: variables.tf not found", vd.full_path));
                        }
                        Ok(tf) => {
                            let tf_vars = parse_tf_variables(&tf);
                            let tf_names: HashSet<&String> = tf_vars.keys().collect();
                            // The engine passes these as -var to every Terraform blueprint,
                            // EXTERNAL included, and terraform aborts on a -var the root module
                            // does not declare. The qbm.yml -> variables.tf check below cannot
                            // catch it: it only walks what qbm.yml already declares, so a
                            // blueprint declaring neither is self-consistent and passes.
                            for injected in ALWAYS_INJECTED_VARIABLES {
                                if !tf_names.iter().any(|n| n.as_str() == injected) {
                                    errors.push(format!(
                                        "{}: '{}' is injected into every Terraform blueprint but is not declared in variables.tf. \
                                         Add a `variable \"{}\"` block.",
                                        vd.full_path, injected, injected
                                    ));
                                }
                            }
                            // The engine injects exactly what contextVariables declares, so each
                            // entry's source must be one it knows and must land in variables.tf.
                            for cv in &spec.context_variables {
                                let Some(source) = cv.source.as_deref() else {
                                    errors.push(format!(
                                        "{}: contextVariables entry '{}' has no 'source'; the engine would never fill it",
                                        vd.full_path, cv.name
                                    ));
                                    continue;
                                };
                                match source_targets(source, &cv.name) {
                                    None => errors.push(format!(
                                        "{}: contextVariables entry '{}' has unknown source '{}'. Known sources: cluster.region, cluster.name, cluster.id",
                                        vd.full_path, cv.name, source
                                    )),
                                    Some(targets) => {
                                        for target in targets {
                                            if !tf_names.contains(&target) {
                                                errors.push(format!(
                                                    "{}: source '{}' fills '{}' but variables.tf does not declare it",
                                                    vd.full_path, source, target
                                                ));
                                            }
                                        }
                                    }
                                }
                            }
                            for var in spec.context_variables.iter().chain(spec.variables.iter()) {
                                if !tf_names.contains(&var.name) {
                                    errors.push(format!(
                                        "{}: '{}' declared in qbm.yml but not in variables.tf",
                                        vd.full_path, var.name
                                    ));
                                }
                                validate_var_constraints(&vd.full_path, var, &mut errors);
                                validate_sensitive_naming(&vd.full_path, var, &mut errors);
                                // Cross-check sensitivity between TF and qbm.yml so the console
                                // can't accidentally render a sensitive value as plaintext.
                                if let Some(tf_sensitive) = tf_vars.get(&var.name) {
                                    let qbm_sensitive = var.sensitive.unwrap_or(false);
                                    if *tf_sensitive && !qbm_sensitive {
                                        errors.push(format!(
                                            "{}: '{}' is sensitive in variables.tf but qbm.yml does not set sensitive: true",
                                            vd.full_path, var.name
                                        ));
                                    }
                                    if !*tf_sensitive && qbm_sensitive {
                                        errors.push(format!(
                                            "{}: '{}' is marked sensitive: true in qbm.yml but variables.tf does not set sensitive = true",
                                            vd.full_path, var.name
                                        ));
                                    }
                                }
                            }
                        }
                    }
                }
                Some("helm") => {
                    for var in spec.variables.iter() {
                        validate_var_constraints(&vd.full_path, var, &mut errors);
                        validate_sensitive_naming(&vd.full_path, var, &mut errors);
                    }
                    if engine_chart.is_none() {
                        errors.push(format!(
                            "{}: spec.engine.chart required when engine.type is helm",
                            vd.full_path
                        ));
                    }
                    if engine.and_then(|e| e.terraform.as_ref()).is_some() {
                        errors.push(format!(
                            "{}: spec.engine.terraform block is not allowed when engine.type is helm",
                            vd.full_path
                        ));
                    }
                    if engine.and_then(|e| e.opentofu.as_ref()).is_some() {
                        errors.push(format!(
                            "{}: spec.engine.opentofu block is not allowed when engine.type is helm",
                            vd.full_path
                        ));
                    }
                }
                Some(other) => {
                    errors.push(format!(
                        "{}: unknown spec.engine.type '{}' (expected terraform, opentofu, or helm)",
                        vd.full_path, other
                    ));
                }
                None => {
                    errors.push(format!("{}: missing spec.engine.type", vd.full_path));
                }
            }
        }

        if errors.is_empty() || !errors.iter().any(|e| e.starts_with(&vd.full_path)) {
            println!("OK: {}", vd.full_path);
        }
    }

    if !errors.is_empty() {
        for e in &errors {
            eprintln!("ERROR: {}", e);
        }
        anyhow::bail!("{} validation error(s)", errors.len());
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// List Terraform blueprints (for CI matrix)
// ---------------------------------------------------------------------------

fn list_terraform_blueprints(root: &Path) -> Result<()> {
    let version_dirs = discover_version_dirs(root)?;
    let mut paths: Vec<String> = Vec::new();

    for vd in &version_dirs {
        let qbm_path = root.join(&vd.full_path).join("qbm.yml");
        let content = match std::fs::read_to_string(&qbm_path) {
            Ok(c) => c,
            Err(_) => continue,
        };
        let qbm: ValidateQbm = match serde_yaml::from_str(&content) {
            Ok(q) => q,
            Err(_) => continue,
        };
        let engine_type = qbm.spec.and_then(|s| s.engine).and_then(|e| e.type_);
        if matches!(engine_type.as_deref(), Some("terraform") | Some("opentofu")) {
            paths.push(vd.full_path.clone());
        }
    }

    println!("{}", serde_json::to_string(&paths)?);
    Ok(())
}

// ---------------------------------------------------------------------------
// QBM types for release-notes rendering
// ---------------------------------------------------------------------------

#[derive(Deserialize, Default)]
#[serde(default)]
struct NotesQbm {
    metadata: NotesMetadata,
    spec: Option<NotesSpec>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct NotesMetadata {
    name: Option<String>,
    version: Option<String>,
    description: Option<String>,
    categories: Vec<String>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct NotesSpec {
    variables: Vec<NotesVariable>,
    outputs: Vec<NotesOutput>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct NotesVariable {
    name: Option<String>,
    #[serde(rename = "type")]
    type_: Option<String>,
    required: Option<bool>,
    default: Option<serde_yaml::Value>,
    description: Option<String>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct NotesOutput {
    name: Option<String>,
    description: Option<String>,
}

// ---------------------------------------------------------------------------
// Shared helpers: blueprint qbm.yml discovery + git invocation
// ---------------------------------------------------------------------------

// Mirrors the find -mindepth 4 -maxdepth 4 -name qbm.yml filter that the original bash/python
// CI scripts used. Returns paths relative to `root`, with forward slashes, no leading "./".
fn find_blueprint_qbm_files(root: &Path) -> Result<Vec<String>> {
    let mut out: Vec<String> = Vec::new();
    let dirs = discover_version_dirs(root)?;
    for vd in dirs {
        out.push(format!("{}/qbm.yml", vd.full_path));
    }
    out.sort();
    Ok(out)
}

fn run_git(root: &Path, args: &[&str]) -> Result<String> {
    let output = Command::new("git")
        .args(args)
        .current_dir(root)
        .output()
        .with_context(|| format!("Failed to spawn git {:?}", args))?;
    if !output.status.success() {
        anyhow::bail!(
            "git {:?} failed: {}",
            args,
            String::from_utf8_lossy(&output.stderr)
        );
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

// Non-failing variant: returns empty string on non-zero exit, used to mirror the original
// shell `2>/dev/null || echo ""` semantics (e.g. reading qbm.yml on a ref where it does not exist).
fn run_git_or_empty(root: &Path, args: &[&str]) -> String {
    Command::new("git")
        .args(args)
        .current_dir(root)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default()
}

fn metadata_version_from_yaml(content: &str) -> Option<String> {
    let doc: serde_yaml::Value = serde_yaml::from_str(content).ok()?;
    doc.get("metadata")?
        .get("version")?
        .as_str()
        .map(|s| s.to_string())
}

fn yaml_bool(value: &serde_yaml::Value, key: &str) -> bool {
    value
        .get(key)
        .and_then(serde_yaml::Value::as_bool)
        .unwrap_or(false)
}

fn yaml_str<'a>(value: &'a serde_yaml::Value, key: &str) -> &'a str {
    value
        .get(key)
        .and_then(serde_yaml::Value::as_str)
        .unwrap_or("")
}

/// The engine requires exactly 4 slash-separated segments and q-core matches each against
/// `^[A-Za-z0-9_.-]+$`. Validate the whole constructed tag, not just the suffix: `dir` and
/// `metadata.version` are author-controlled too, so a legal semver build like `1.2.3+build`
/// would otherwise produce a tag that only fails once someone tries to deploy it.
fn validate_blueprint_tag(tag: &str) -> Result<()> {
    let segments: Vec<&str> = tag.split('/').collect();
    if segments.len() != 4 {
        anyhow::bail!(
            "tag {:?} must have exactly 4 slash-separated segments, got {}",
            tag,
            segments.len()
        );
    }
    for segment in &segments {
        let ok = !segment.is_empty()
            && *segment != "."
            && *segment != ".."
            && segment
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-' || c == '_');
        if !ok {
            anyhow::bail!(
                "tag {:?} has invalid segment {:?}: every segment must match ^[A-Za-z0-9_.-]+$",
                tag,
                segment
            );
        }
    }
    Ok(())
}

/// Manifest-derived inputs for the PR comment's ready-to-run payloads. `declared_names` and
/// `required_names` are carried alongside the payload rather than as fields on each entry, so the
/// flags never leak into the JSON a tester pastes.
#[derive(Default)]
struct PayloadHints {
    icon: String,
    /// Payload entries, one per variable carrying a non-empty `default:`.
    variables: Vec<serde_json::Value>,
    /// `{name, is_secret}` for each required variable the manifest cannot pre-fill — named in the
    /// comment so a tester adds them deliberately instead of discovering them from a rejected call.
    variables_to_add: Vec<serde_json::Value>,
    /// Every variable the manifest declares, whether or not it made it into `variables`.
    declared_names: HashSet<String>,
    required_names: HashSet<String>,
}

/// Icon and create-payload variables from a manifest, so `prerelease` can emit a payload a tester
/// can run as-is instead of transcribing `qbm.yml` by hand. Only variables carrying a non-empty
/// `default:` become entries; every other one is left out of the payload entirely.
///
/// Sending a variable with no value is not a neutral placeholder, it is the one shape that fails
/// silently: the Qovery terraform provider rejects an empty variable value while the engine applies
/// the meta-module, so the call succeeds and no Terraform service is ever created — the same defect
/// the `default: ""` ban keeps out of the manifests (see AGENTS.md). Omitting the variable instead
/// resolves it from `variables.tf` or a `{% if var %}` guard, and for a required one fails the API
/// call outright, naming it. So required variables with no default come back in `variables_to_add`
/// for the comment to list, not as empty payload entries.
fn payload_hints_from_yaml(content: &str) -> PayloadHints {
    let Ok(doc) = serde_yaml::from_str::<serde_yaml::Value>(content) else {
        return PayloadHints::default();
    };

    let icon = doc
        .get("metadata")
        .and_then(|m| m.get("icon"))
        .and_then(|i| i.as_str())
        .unwrap_or_default()
        .to_string();

    let mut variables = Vec::new();
    let mut variables_to_add = Vec::new();
    let mut declared_names = HashSet::new();
    let mut required_names = HashSet::new();

    if let Some(seq) = doc
        .get("spec")
        .and_then(|s| s.get("variables"))
        .and_then(|v| v.as_sequence())
    {
        for var in seq {
            let Some(name) = var.get("name").and_then(serde_yaml::Value::as_str) else {
                continue;
            };
            declared_names.insert(name.to_string());
            let required = yaml_bool(var, "required");
            if required {
                required_names.insert(name.to_string());
            }
            // An explicit `default: ""` counts as no default: an empty value is exactly what the
            // provider refuses, so it could never be delivered anyway.
            let default = yaml_str(var, "default");
            let (target, mut entry) = if default.is_empty() {
                // An optional variable with no default is simply absent — nothing for a tester to
                // do, since unset is what its description already documents.
                if !required {
                    continue;
                }
                (&mut variables_to_add, serde_json::json!({ "name": name }))
            } else {
                (
                    &mut variables,
                    serde_json::json!({ "name": name, "value": default }),
                )
            };
            if yaml_bool(var, "sensitive") {
                entry["is_secret"] = serde_json::Value::Bool(true);
            }
            target.push(entry);
        }
    }

    PayloadHints {
        icon,
        variables,
        variables_to_add,
        declared_names,
        required_names,
    }
}

// ---------------------------------------------------------------------------
// check-version-bump
// ---------------------------------------------------------------------------

/// Blueprint directories with at least one file changed since `base_ref`.
fn changed_blueprint_dirs(root: &Path, base_ref: &str) -> Result<Vec<String>> {
    let diff = run_git(root, &["diff", "--name-only", &format!("{}...HEAD", base_ref)])?;
    let changed_files: Vec<&str> = diff.lines().filter(|l| !l.is_empty()).collect();

    let qbm_files = find_blueprint_qbm_files(root)?;

    let mut changed_blueprints: Vec<String> = Vec::new();
    for qbm in &qbm_files {
        let dir = match qbm.strip_suffix("/qbm.yml") {
            Some(d) => d,
            None => continue,
        };
        let prefix = format!("{}/", dir);
        if changed_files.iter().any(|f| f.starts_with(&prefix)) {
            changed_blueprints.push(dir.to_string());
        }
    }

    Ok(changed_blueprints)
}

fn check_version_bump(root: &Path, base_ref: &str) -> Result<()> {
    let changed_blueprints = changed_blueprint_dirs(root, base_ref)?;

    if changed_blueprints.is_empty() {
        println!("No blueprint directories changed.");
        return Ok(());
    }

    let mut errors: Vec<String> = Vec::new();
    for dir in &changed_blueprints {
        println!("Checking {}...", dir);

        let old_content =
            run_git_or_empty(root, &["show", &format!("{}:{}/qbm.yml", base_ref, dir)]);
        let old_version = metadata_version_from_yaml(&old_content).unwrap_or_default();

        let new_path = root.join(dir).join("qbm.yml");
        let new_content = std::fs::read_to_string(&new_path)
            .with_context(|| format!("Failed to read {}", new_path.display()))?;
        let new_version = metadata_version_from_yaml(&new_content).unwrap_or_default();

        if old_version.is_empty() {
            println!("  New blueprint (no version on {}). OK.", base_ref);
            continue;
        }

        if old_version == new_version {
            errors.push(format!(
                "{} has file changes but metadata.version was not bumped (still {})",
                dir, old_version
            ));
        } else {
            println!("  Version bumped: {} → {}. OK.", old_version, new_version);
        }
    }

    if !errors.is_empty() {
        for e in &errors {
            eprintln!("ERROR: {}", e);
        }
        anyhow::bail!("{} version-bump error(s)", errors.len());
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// auto-tag + release notes
// ---------------------------------------------------------------------------

// Python's str() output for YAML-loaded values, used inside the default-column backticks so the
// rendered markdown matches the original script byte-for-byte even for non-string defaults.
fn render_yaml_default(v: &serde_yaml::Value) -> String {
    match v {
        serde_yaml::Value::Null => "None".to_string(),
        serde_yaml::Value::Bool(b) => {
            if *b {
                "True".to_string()
            } else {
                "False".to_string()
            }
        }
        serde_yaml::Value::Number(n) => n.to_string(),
        serde_yaml::Value::String(s) => s.clone(),
        // Sequences/mappings rarely appear as defaults; fall back to yaml repr (best-effort).
        other => serde_yaml::to_string(other)
            .unwrap_or_default()
            .trim_end()
            .to_string(),
    }
}

// Python: desc[:77] + '...' when len(desc) > 80. Operates on Unicode codepoints.
fn truncate_description(desc: &str) -> String {
    let count = desc.chars().count();
    if count > 80 {
        let head: String = desc.chars().take(77).collect();
        format!("{}...", head)
    } else {
        desc.to_string()
    }
}

struct ReleaseNotes {
    title: String,
    body: String,
}

fn build_release_notes(root: &Path, tag: &str) -> Result<ReleaseNotes> {
    let parts: Vec<&str> = tag.split('/').collect();
    if parts.len() < 4 {
        anyhow::bail!("Tag '{}' does not match provider/service/variant/version", tag);
    }
    let version = parts[parts.len() - 1];
    let dir_path = parts[..parts.len() - 1].join("/");
    let provider = parts[0];

    let qbm_path = root.join(&dir_path).join("qbm.yml");
    let content = std::fs::read_to_string(&qbm_path)
        .with_context(|| format!("Failed to read {}", qbm_path.display()))?;
    let qbm: NotesQbm =
        serde_yaml::from_str(&content).with_context(|| format!("Failed to parse {}", qbm_path.display()))?;

    let name = qbm.metadata.name.clone().unwrap_or_else(|| dir_path.clone());
    let description = qbm.metadata.description.clone().unwrap_or_default();
    let categories = qbm.metadata.categories.clone();

    // Previous tag under the same blueprint dir, by version-sort. Mirrors:
    //   git tag -l 'dir_path/*' --sort=-version:refname
    let sibling_raw = run_git(
        root,
        &["tag", "-l", &format!("{}/*", dir_path), "--sort=-version:refname"],
    )?;
    let sibling_tags: Vec<&str> = sibling_raw
        .lines()
        .filter(|l| !l.is_empty() && *l != tag)
        .collect();
    let prev_tag = sibling_tags.first().copied();

    let changes: String = if let Some(prev) = prev_tag {
        let log = run_git(
            root,
            &[
                "log",
                &format!("{}..HEAD", prev),
                "--oneline",
                "--",
                &format!("{}/", dir_path),
            ],
        )?;
        let commits: Vec<&str> = log.lines().filter(|l| !l.is_empty()).collect();
        if commits.is_empty() {
            "_No changes recorded_".to_string()
        } else {
            commits
                .iter()
                .map(|c| format!("- {}", c))
                .collect::<Vec<_>>()
                .join("\n")
        }
    } else {
        "_Initial release_".to_string()
    };

    let spec = qbm.spec.unwrap_or_default();

    let mut config_rows: Vec<String> = Vec::new();
    for v in &spec.variables {
        let req = if v.required.unwrap_or(false) { "Yes" } else { "No" };
        let default = match &v.default {
            Some(d) => format!("`{}`", render_yaml_default(d)),
            None => "—".to_string(),
        };
        let desc = truncate_description(v.description.as_deref().unwrap_or(""));
        config_rows.push(format!(
            "| {} | {} | {} | {} | {} |",
            v.name.as_deref().unwrap_or(""),
            v.type_.as_deref().unwrap_or(""),
            req,
            default,
            desc,
        ));
    }

    let output_rows: Vec<String> = spec
        .outputs
        .iter()
        .map(|o| {
            format!(
                "| {} | {} |",
                o.name.as_deref().unwrap_or(""),
                o.description.as_deref().unwrap_or("")
            )
        })
        .collect();

    let cats_str = categories.join(", ");
    let mut meta_line = format!("**Provider:** {}", provider);
    if !cats_str.is_empty() {
        meta_line.push_str(&format!(" | **Categories:** {}", cats_str));
    }

    let mut lines: Vec<String> = vec![
        format!("## {} · v{}", name, version),
        String::new(),
        format!("> {}", description),
        String::new(),
        meta_line,
        String::new(),
        "---".to_string(),
        String::new(),
        "### What's new".to_string(),
        String::new(),
        changes,
    ];

    if !config_rows.is_empty() {
        lines.extend([
            String::new(),
            "---".to_string(),
            String::new(),
            "### Configuration".to_string(),
            String::new(),
            "| Variable | Type | Required | Default | Description |".to_string(),
            "|---|---|---|---|---|".to_string(),
        ]);
        lines.extend(config_rows);
    }

    if !output_rows.is_empty() {
        lines.extend([
            String::new(),
            "### Outputs".to_string(),
            String::new(),
            "| Name | Description |".to_string(),
            "|---|---|".to_string(),
        ]);
        lines.extend(output_rows);
    }

    Ok(ReleaseNotes {
        title: format!("{} v{}", name, version),
        body: lines.join("\n"),
    })
}

/// Tag each changed blueprint at `{dir}/{metadata.version}-{suffix}` so a PR branch can be
/// deployed on real Qovery before merge. The engine clones a blueprint by git tag and only uses
/// the 4th tag segment as a label, so a prerelease tag is a first-class deployable ref.
///
/// Deliberately never creates a GitHub release: `auto-tag` only releases tags pointing at main's
/// HEAD, so these stay invisible to the normal publish flow.
fn prerelease(args: &PrereleaseArgs) -> Result<()> {
    let root = args.root.canonicalize().context("Invalid root path")?;

    if args.suffix.trim().is_empty() {
        anyhow::bail!("--suffix must not be empty");
    }
    // The tag has to survive the engine's segment charset and q-core's ^[A-Za-z0-9_.-]+$ check.
    let suffix_is_tag_safe = args
        .suffix
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-' || c == '_');
    if !suffix_is_tag_safe {
        anyhow::bail!(
            "--suffix {:?} must only contain [A-Za-z0-9._-]; anything else breaks the blueprint tag format",
            args.suffix
        );
    }
    // The tag ruleset excludes `refs/tags/**/*-rc` from its deletion rule, and fnmatch `*` stops
    // at `/` — so only a tag whose last segment ends in `-rc` can ever be cleaned up.
    if !args.suffix.ends_with("-rc") {
        anyhow::bail!(
            "--suffix {:?} must end in '-rc', otherwise the tag falls outside the ruleset's deletion exclusion and can never be removed",
            args.suffix
        );
    }

    let changed = changed_blueprint_dirs(&root, &args.base_ref)?;
    if changed.is_empty() {
        eprintln!("No blueprint directories changed — nothing to prerelease.");
        return Ok(());
    }

    let mut tags: Vec<String> = Vec::new();
    let mut entries: Vec<serde_json::Value> = Vec::new();
    for dir in &changed {
        let qbm_path = root.join(dir).join("qbm.yml");
        let content = std::fs::read_to_string(&qbm_path)
            .with_context(|| format!("Failed to read {}", qbm_path.display()))?;
        let version = match metadata_version_from_yaml(&content) {
            Some(v) if !v.is_empty() => v,
            _ => {
                eprintln!("Warning: no metadata.version in {}/qbm.yml, skipping", dir);
                continue;
            }
        };

        let tag = format!("{}/{}-{}", dir, version, args.suffix);
        validate_blueprint_tag(&tag)?;
        // Never `tag -f`: the repo's tag ruleset forbids non-fast-forward updates. Callers pass a
        // suffix that identifies the commit, so an existing tag already points at this content.
        //
        // Resolve the ref rather than matching `git tag -l` output: on a case-insensitive
        // filesystem a new `AWS/...` tag lands in this repo's legacy lowercase `aws/...` ref
        // directory, so the listing reports a name that never string-matches what we built.
        let tag_ref = format!("refs/tags/{}", tag);
        let exists = !run_git_or_empty(&root, &["rev-parse", "-q", "--verify", &tag_ref])
            .trim()
            .is_empty();
        if args.dry_run {
            eprintln!("[dry-run] would tag {}", tag);
        } else if exists {
            eprintln!("Tag {} already exists, skipping", tag);
        } else {
            run_git(&root, &["tag", &tag])?;
            eprintln!("Tagged {}", tag);
        }

        let hints = payload_hints_from_yaml(&content);

        // An update is a JSON-merge-patch: any key present overwrites the deployed value. Sending
        // every required variable would therefore clobber the live config with whatever the
        // manifest happens to know, which for a required one is nothing at all. So the update
        // payload carries only variables this branch newly introduces, which are the ones an
        // existing service cannot already have.
        let base_qbm = format!("{}:{}/qbm.yml", args.base_ref, dir);
        let base_manifest = run_git_or_empty(&root, &["show", &base_qbm]);
        let is_new_blueprint = base_manifest.trim().is_empty();

        // The already-published tag, plus the payload that creates a service on it. Testing the
        // update path needs a service that starts on the OLD version — creating one at the rc tag
        // and then updating it to the same tag would diff nothing.
        let base_hints = payload_hints_from_yaml(&base_manifest);
        let base_tag = metadata_version_from_yaml(&base_manifest)
            .filter(|v| !v.is_empty())
            .map(|v| format!("{}/{}", dir, v));

        // Two kinds of variable an existing service cannot already hold a value for, and nothing
        // else — resending a variable the service already has would overwrite the deployed value:
        //   - one this branch declares for the first time (optional included: with no stored value,
        //     its `{{ var }}` would be undefined at render time);
        //   - one promoted from optional to required, since a service created before the promotion
        //     may never have been given a value for it.
        // Judged against every variable the base manifest declared, not just the ones it could
        // pre-fill: a variable the base already had is one the deployed service may hold a value
        // for, whether or not that value came from a default.
        let is_new_to_branch = |v: &serde_json::Value| {
            v.get("name")
                .and_then(serde_json::Value::as_str)
                .is_some_and(|n| {
                    !base_hints.declared_names.contains(n)
                        || (hints.required_names.contains(n)
                            && !base_hints.required_names.contains(n))
                })
        };
        let update_variables: Vec<&serde_json::Value> = hints
            .variables
            .iter()
            .filter(|v| is_new_to_branch(v))
            .collect();
        let update_variables_to_add: Vec<&serde_json::Value> = hints
            .variables_to_add
            .iter()
            .filter(|v| is_new_to_branch(v))
            .collect();

        entries.push(serde_json::json!({
            "tag": tag,
            "dir": dir,
            "icon": hints.icon,
            "variables": hints.variables,
            "variables_to_add": hints.variables_to_add,
            "update_variables": update_variables,
            "update_variables_to_add": update_variables_to_add,
            "is_new_blueprint": is_new_blueprint,
            "base_tag": base_tag,
            "base_icon": base_hints.icon,
            "base_variables": base_hints.variables,
            "base_variables_to_add": base_hints.variables_to_add,
        }));
        tags.push(tag);
    }

    if tags.is_empty() {
        eprintln!("No taggable blueprints found — nothing to prerelease.");
        return Ok(());
    }

    if args.dry_run {
        eprintln!("[dry-run] no refs created, nothing pushed");
    } else if !args.no_push {
        // Push these refs explicitly, never `--tags` (that would leak unrelated local tags) and
        // never `--force`. Re-pushing an unchanged tag is a no-op; a mismatch should fail loudly.
        let mut push_args: Vec<&str> = vec!["push", &args.remote];
        push_args.extend(tags.iter().map(String::as_str));
        run_git(&root, &push_args)?;
    } else {
        eprintln!("--no-push: tags created locally, not pushed. Remove with:");
        for tag in &tags {
            eprintln!("  git tag -d {}", tag);
        }
    }

    // stdout is machine-readable (tag + the fields needed to build a deploy payload); progress
    // goes to stderr.
    println!("{}", serde_json::to_string_pretty(&entries)?);

    Ok(())
}

fn auto_tag(args: &AutoTagArgs) -> Result<()> {
    let root = args.root.canonicalize().context("Invalid root path")?;

    let qbm_files = find_blueprint_qbm_files(&root)?;

    let existing_raw = run_git(&root, &["tag", "-l"])?;
    let existing: HashSet<String> = existing_raw
        .lines()
        .filter(|l| !l.is_empty())
        .map(String::from)
        .collect();

    let mut new_tags: Vec<String> = Vec::new();
    // Every tag a manifest on HEAD declares, whether created just now or by an earlier run. This
    // is what makes a tag releasable — see the release filter below.
    let mut declared_tags: HashSet<String> = HashSet::new();
    for qbm in &qbm_files {
        let dir = qbm.strip_suffix("/qbm.yml").unwrap();
        let content = std::fs::read_to_string(root.join(qbm))
            .with_context(|| format!("Failed to read {}", qbm))?;
        let version = match metadata_version_from_yaml(&content) {
            Some(v) if !v.is_empty() => v,
            _ => {
                println!("Warning: no version in {}, skipping", qbm);
                continue;
            }
        };
        let tag = format!("{}/{}", dir, version);
        declared_tags.insert(tag.clone());
        if existing.contains(&tag) {
            println!("Tag {} already exists, skipping", tag);
        } else {
            run_git(&root, &["tag", &tag])?;
            println!("Created tag: {}", tag);
            new_tags.push(tag);
        }
    }

    if !new_tags.is_empty() && !args.no_push {
        run_git(&root, &["push", &args.remote, "--tags"])?;
    }

    // gh release create runs against tags pointing at HEAD that a manifest actually declares.
    //
    // Membership in `declared_tags`, not the shape of the name, is what makes a tag a release: it
    // is released precisely because some `qbm.yml` on HEAD asks for that version. That admits any
    // version an author chooses — `1.2.3-rc`, `1.2.3-pr45.abc-rc`, anything — and excludes tags
    // nothing declares, which is what a `prerelease` tag left behind by a fast-forward merge is.
    // Guessing from the suffix instead cannot separate those two cases, because the suffix is
    // author-controlled.
    let head_tags_raw = run_git(&root, &["tag", "--points-at", "HEAD"])?;
    let release_tags: Vec<String> = head_tags_raw
        .lines()
        .map(str::trim)
        .filter(|l| declared_tags.contains(*l))
        .map(String::from)
        .collect();

    if release_tags.is_empty() {
        println!("No blueprint tags on HEAD — nothing to release.");
        return Ok(());
    }

    if args.no_release {
        for tag in &release_tags {
            println!("[dry-run] would create release for {}", tag);
        }
        return Ok(());
    }

    for tag in &release_tags {
        let check = Command::new("gh")
            .args(["release", "view", tag])
            .current_dir(&root)
            .output()
            .with_context(|| format!("Failed to spawn gh release view {}", tag))?;
        if check.status.success() {
            println!("Release {} already exists, skipping", tag);
            continue;
        }

        let notes = build_release_notes(&root, tag)?;

        // Write the body to a tempfile so `gh release create` can read it; matches the
        // /tmp/release_notes_{version}.md pattern in the original Python.
        let version = tag.rsplit('/').next().unwrap_or("unknown");
        let safe_version: String = version
            .chars()
            .map(|c| if c.is_alphanumeric() || c == '.' || c == '-' || c == '_' { c } else { '_' })
            .collect();
        let notes_path = std::env::temp_dir().join(format!("release_notes_{}.md", safe_version));
        std::fs::write(&notes_path, &notes.body)
            .with_context(|| format!("Failed to write {}", notes_path.display()))?;

        let status = Command::new("gh")
            .args([
                "release",
                "create",
                tag,
                "--title",
                &notes.title,
                "--notes-file",
            ])
            .arg(&notes_path)
            .current_dir(&root)
            .status()
            .with_context(|| format!("Failed to spawn gh release create {}", tag))?;
        if !status.success() {
            anyhow::bail!("gh release create {} failed", tag);
        }
        println!("Released {}", tag);
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Generate(args) => {
            let root = args.root.canonicalize().context("Invalid root path")?;
            let catalog = generate_catalog(&root)?;
            let json = serde_json::to_string_pretty(&catalog)?;
            std::fs::write(&args.output, format!("{}\n", json))
                .with_context(|| format!("Failed to write {}", args.output.display()))?;
            eprintln!(
                "Generated {} ({} blueprints)",
                args.output.display(),
                catalog.blueprints.len()
            );
        }
        Commands::Validate(args) => {
            let root = args.root.canonicalize().context("Invalid root path")?;
            validate_blueprints(&root)?;
            eprintln!("All blueprints valid.");
        }
        Commands::ListTerraform(args) => {
            let root = args.root.canonicalize().context("Invalid root path")?;
            list_terraform_blueprints(&root)?;
        }
        Commands::CheckVersionBump(args) => {
            let root = args.root.canonicalize().context("Invalid root path")?;
            check_version_bump(&root, &args.base_ref)?;
        }
        Commands::AutoTag(args) => {
            auto_tag(&args)?;
        }
        Commands::Prerelease(args) => {
            prerelease(&args)?;
        }
    }

    Ok(())
}
