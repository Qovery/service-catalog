use anyhow::{Context, Result};
use chrono::Utc;
use clap::{Parser, Subcommand};
use regex::Regex;
use semver::Version;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashSet};
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

// ---------------------------------------------------------------------------
// QBM types for catalog generation
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct Qbm {
    kind: Option<String>,
    metadata: QbmMetadata,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct QbmMetadata {
    name: String,
    #[allow(dead_code)]
    version: String,
    description: Option<String>,
    icon: Option<String>,
    service_family: Option<String>,
    categories: Option<Vec<String>>,
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
    engine: Option<String>,
    provider: Option<String>,
    chart: Option<serde_yaml::Value>,
    variables: Vec<VarDecl>,
    #[serde(rename = "contextVariables")]
    context_variables: Vec<VarDecl>,
    stages: Option<serde_yaml::Value>,
}

#[derive(Deserialize)]
struct VarDecl {
    name: String,
    #[serde(rename = "type")]
    type_: Option<String>,
    default: Option<String>,
    #[serde(rename = "allowedValues")]
    allowed_values: Option<Vec<String>>,
    min: Option<f64>,
    max: Option<f64>,
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
// Git helpers
// ---------------------------------------------------------------------------

fn list_tags_for_version_dir(root: &Path, version_path: &str) -> Result<Vec<(Version, String)>> {
    let pattern = format!("{}/*", version_path);
    let output = Command::new("git")
        .args(["tag", "-l", &pattern])
        .current_dir(root)
        .output()
        .context("Failed to run git tag -l")?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut versions: Vec<(Version, String)> = Vec::new();

    for line in stdout.lines() {
        let tag = line.trim();
        if tag.is_empty() {
            continue;
        }
        let prefix = format!("{}/", version_path);
        if let Some(version_str) = tag.strip_prefix(&prefix) {
            match Version::parse(version_str) {
                Ok(ver) => versions.push((ver, tag.to_string())),
                Err(e) => {
                    eprintln!("Warning: skipping tag '{}': invalid semver: {}", tag, e);
                }
            }
        }
    }

    versions.sort_by(|a, b| b.0.cmp(&a.0));
    Ok(versions)
}

fn git_show_file(root: &Path, tag: &str, file_path: &str) -> Result<String> {
    let spec = format!("{}:{}", tag, file_path);
    let output = Command::new("git")
        .args(["show", &spec])
        .current_dir(root)
        .output()
        .with_context(|| format!("Failed to run git show {}", spec))?;

    if !output.status.success() {
        anyhow::bail!(
            "git show {} failed: {}",
            spec,
            String::from_utf8_lossy(&output.stderr)
        );
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
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
            let tags = list_tags_for_version_dir(root, &vd.full_path)?;
            let latest_tag = tags.first().map(|(_, tag)| tag.clone());

            if top_qbm.is_none() {
                let qbm = if let Some(ref tag) = latest_tag {
                    let qbm_file = format!("{}/qbm.yml", vd.full_path);
                    match git_show_file(root, tag, &qbm_file) {
                        Ok(content) => serde_yaml::from_str::<Qbm>(&content).ok(),
                        Err(e) => {
                            eprintln!(
                                "Warning: failed to read qbm.yml from tag '{}': {}. Falling back to working tree.",
                                tag, e
                            );
                            std::fs::read_to_string(root.join(&vd.full_path).join("qbm.yml"))
                                .ok()
                                .and_then(|c| serde_yaml::from_str(&c).ok())
                        }
                    }
                } else {
                    std::fs::read_to_string(root.join(&vd.full_path).join("qbm.yml"))
                        .ok()
                        .and_then(|c| serde_yaml::from_str(&c).ok())
                };
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

        catalog_blueprints.push(CatalogBlueprint {
            name: qbm.metadata.name,
            kind: qbm.kind.unwrap_or_else(|| "ServiceBlueprint".to_string()),
            description: qbm.metadata.description.unwrap_or_default(),
            icon: qbm.metadata.icon,
            categories: qbm.metadata.categories.unwrap_or_default(),
            provider: version_dirs[0].provider.clone(),
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
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

fn validate_blueprints(root: &Path) -> Result<()> {
    let version_dirs = discover_version_dirs(root)?;
    let tf_var_re = Regex::new(r#"variable\s+"(\w+)""#).unwrap();
    let mut errors: Vec<String> = Vec::new();

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
            match spec.engine.as_deref() {
                Some("terraform") | Some("opentofu") => {
                    if spec.provider.is_none() {
                        errors.push(format!(
                            "{}: spec.provider required when engine is terraform/opentofu",
                            vd.full_path
                        ));
                    }
                    let vars_path = root.join(&vd.full_path).join("variables.tf");
                    match std::fs::read_to_string(&vars_path) {
                        Err(_) => {
                            errors.push(format!("{}: variables.tf not found", vd.full_path));
                        }
                        Ok(tf) => {
                            let tf_vars: HashSet<String> = tf_var_re
                                .captures_iter(&tf)
                                .map(|c| c[1].to_string())
                                .collect();
                            for var in spec.context_variables.iter().chain(spec.variables.iter()) {
                                if !tf_vars.contains(&var.name) {
                                    errors.push(format!(
                                        "{}: '{}' declared in qbm.yml but not in variables.tf",
                                        vd.full_path, var.name
                                    ));
                                }
                                validate_var_constraints(&vd.full_path, var, &mut errors);
                            }
                        }
                    }
                }
                Some("helm") => {
                    for var in spec.variables.iter() {
                        validate_var_constraints(&vd.full_path, var, &mut errors);
                    }
                    if spec.chart.is_none() {
                        errors.push(format!(
                            "{}: spec.chart required when engine is helm",
                            vd.full_path
                        ));
                    }
                }
                Some(other) => {
                    errors.push(format!(
                        "{}: unknown spec.engine '{}' (expected terraform, opentofu, or helm)",
                        vd.full_path, other
                    ));
                }
                None => {
                    errors.push(format!("{}: missing spec.engine", vd.full_path));
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
        let engine = qbm.spec.and_then(|s| s.engine);
        if matches!(engine.as_deref(), Some("terraform") | Some("opentofu")) {
            paths.push(vd.full_path.clone());
        }
    }

    println!("{}", serde_json::to_string(&paths)?);
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
    }

    Ok(())
}
