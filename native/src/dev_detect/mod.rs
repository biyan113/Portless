//! Recognize common local-dev stacks from process name + command line.

use std::path::Path;

#[derive(Debug, Clone)]
pub struct DevIdentity {
    pub stack: String,
    pub is_dev: bool,
    pub project_name: Option<String>,
}

pub fn identify(
    process_name: &str,
    command_line: Option<&str>,
    working_directory: Option<&str>,
    executable_path: Option<&str>,
) -> DevIdentity {
    let name = process_name.to_lowercase();
    let cmd = command_line.unwrap_or("").to_lowercase();
    let exe = executable_path.unwrap_or("").to_lowercase();
    let blob = format!("{name} {cmd} {exe}");

    let stack = detect_stack(&name, &cmd, &blob);
    let is_dev = stack.is_some()
        || matches!(
            name.as_str(),
            "node"
                | "nodejs"
                | "deno"
                | "bun"
                | "python"
                | "python3"
                | "ruby"
                | "php"
                | "java"
                | "dotnet"
                | "go"
                | "cargo"
                | "rustc"
                | "dart"
                | "flutter"
                | "vite"
                | "next-server"
                | "webpack"
                | "webpack-dev-server"
        );

    let project_name = working_directory
        .map(Path::new)
        .and_then(|p| p.file_name())
        .and_then(|s| s.to_str())
        .map(|s| s.to_string());

    DevIdentity {
        stack: stack.unwrap_or_else(|| pretty_process_name(process_name)),
        is_dev,
        project_name,
    }
}

fn detect_stack(name: &str, cmd: &str, blob: &str) -> Option<String> {
    // Order matters: more specific first.
    let rules: &[(&[&str], &str)] = &[
        (&["next-server", "next dev", "next start", "/next "], "Next.js"),
        (&["vite", "vite.js"], "Vite"),
        (&["nuxt"], "Nuxt"),
        (&["webpack-dev-server", "webpack serve"], "Webpack"),
        (&["react-native", "metro"], "React Native"),
        (&["expo"], "Expo"),
        (&["astro"], "Astro"),
        (&["remix"], "Remix"),
        (&["svelte-kit", "sveltekit"], "SvelteKit"),
        (&["nestjs", "@nestjs"], "NestJS"),
        (&["express"], "Express"),
        (&["fastify"], "Fastify"),
        (&["uvicorn"], "Uvicorn"),
        (&["gunicorn"], "Gunicorn"),
        (&["fastapi"], "FastAPI"),
        (&["django", "manage.py runserver"], "Django"),
        (&["flask"], "Flask"),
        (&["streamlit"], "Streamlit"),
        (&["jupyter"], "Jupyter"),
        (&["postgres", "postgresql"], "PostgreSQL"),
        (&["redis-server", "redis"], "Redis"),
        (&["mysqld", "mysql"], "MySQL"),
        (&["mongod", "mongodb"], "MongoDB"),
        (&["docker", "com.docker"], "Docker"),
        (&["com.docker.backend"], "Docker"),
        (&["kubectl"], "Kubernetes"),
        (&["cargo run", "target/debug", "target/release"], "Rust"),
        (&["go run", "air ", "__debug_bin"], "Go"),
        (&["gradle", "spring-boot"], "Spring"),
        (&["tomcat"], "Tomcat"),
        (&["php -s", "artisan serve"], "PHP"),
        (&["rails s", "puma", "ruby"], "Ruby"),
        (&["dart", "flutter"], "Flutter/Dart"),
        (&["bun "], "Bun"),
        (&["deno "], "Deno"),
        (&["node"], "Node.js"),
        (&["python"], "Python"),
        (&["java"], "Java"),
    ];

    for (needles, label) in rules {
        for n in *needles {
            if name.contains(n) || cmd.contains(n) || blob.contains(n) {
                return Some((*label).to_string());
            }
        }
    }
    None
}

fn pretty_process_name(name: &str) -> String {
    if name.is_empty() {
        return "Unknown".into();
    }
    name.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_vite() {
        let id = identify(
            "node",
            Some("node /Users/me/app/node_modules/.bin/vite --host"),
            Some("/Users/me/app"),
            Some("/opt/homebrew/bin/node"),
        );
        assert_eq!(id.stack, "Vite");
        assert!(id.is_dev);
        assert_eq!(id.project_name.as_deref(), Some("app"));
    }
}
