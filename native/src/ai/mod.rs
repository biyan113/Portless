//! DeepSeek-powered process / port explanation.
//! AI always returns the same JSON schema; UI renders a fixed template.

use crate::models::PortProcess;
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;

const DEFAULT_BASE: &str = "https://api.deepseek.com";
const DEFAULT_MODEL: &str = "deepseek-v4-flash";

/// Fixed fields for every process insight card.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProcessInsight {
    /// 一句话结论
    pub headline: String,
    /// 服务名（展示用）
    pub service_name: String,
    /// dev | system | database | proxy | runtime | unknown
    pub category: String,
    /// 技术栈，如 Node.js / Vite / PostgreSQL
    pub stack: String,
    /// 用途与场景
    pub purpose: String,
    /// 是否像本地开发服务
    pub is_dev_service: bool,
    /// safe | caution | do_not
    pub stop_advice: String,
    /// 停止后的影响
    pub stop_impact: String,
    /// 0.0 ~ 1.0
    pub confidence: f32,
    /// 1–3 条可操作建议
    pub actions: Vec<String>,
    /// 可选风险点
    pub risks: Vec<String>,
    /// 补充说明；未知信息写这里
    pub notes: String,
}

impl ProcessInsight {
    pub fn normalize(mut self) -> Self {
        self.headline = trim_or(&self.headline, "未知服务");
        self.service_name = trim_or(&self.service_name, "Unknown");
        self.category = normalize_category(&self.category);
        self.stack = trim_or(&self.stack, "未知");
        self.purpose = trim_or(&self.purpose, "信息不足，无法判断用途");
        self.stop_advice = normalize_stop(&self.stop_advice);
        self.stop_impact = trim_or(&self.stop_impact, "停止影响未知");
        if !(0.0..=1.0).contains(&self.confidence) {
            self.confidence = self.confidence.clamp(0.0, 1.0);
        }
        self.actions = self
            .actions
            .into_iter()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .take(5)
            .collect();
        if self.actions.is_empty() {
            self.actions.push("在 Portless 中查看完整路径与命令行后再决定是否停止".into());
        }
        self.risks = self
            .risks
            .into_iter()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .take(5)
            .collect();
        self.notes = self.notes.trim().to_string();
        self
    }

    /// Stable plain-text summary (for logs / fallback).
    pub fn to_summary_text(&self) -> String {
        let advice = match self.stop_advice.as_str() {
            "safe" => "可停",
            "do_not" => "勿动",
            _ => "慎停",
        };
        format!(
            "{}\n服务: {} | 分类: {} | 技术栈: {}\n用途: {}\n停止建议: {} — {}\n操作: {}",
            self.headline,
            self.service_name,
            self.category,
            self.stack,
            self.purpose,
            advice,
            self.stop_impact,
            self.actions.join("；")
        )
    }
}

fn trim_or(s: &str, fallback: &str) -> String {
    let t = s.trim();
    if t.is_empty() {
        fallback.into()
    } else {
        t.to_string()
    }
}

fn normalize_category(s: &str) -> String {
    match s.trim().to_ascii_lowercase().as_str() {
        "dev" | "development" | "local" => "dev".into(),
        "system" | "os" => "system".into(),
        "database" | "db" | "data" => "database".into(),
        "proxy" | "vpn" | "tunnel" => "proxy".into(),
        "runtime" | "language" | "vm" => "runtime".into(),
        _ => "unknown".into(),
    }
}

fn normalize_stop(s: &str) -> String {
    let t = s.trim().to_ascii_lowercase();
    if matches!(t.as_str(), "safe" | "ok" | "可停" | "可以停止") {
        "safe".into()
    } else if matches!(t.as_str(), "do_not" | "dont" | "don't" | "forbid" | "勿动" | "不可停") {
        "do_not".into()
    } else {
        "caution".into()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiConfig {
    pub api_key: Option<String>,
    pub base_url: String,
    pub model: String,
    pub thinking: bool,
}

impl Default for AiConfig {
    fn default() -> Self {
        Self {
            api_key: None,
            base_url: DEFAULT_BASE.into(),
            model: DEFAULT_MODEL.into(),
            thinking: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiStatus {
    pub configured: bool,
    pub model: String,
    pub base_url: String,
    pub key_hint: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExplainResult {
    pub ok: bool,
    pub model: String,
    /// Human-readable summary (always same order of sections).
    pub summary: String,
    /// Raw model text (usually JSON string).
    pub raw: String,
    /// Structured insight — every successful call has the same keys.
    pub data: Option<ProcessInsight>,
    pub message: Option<String>,
}

pub fn load_config() -> AiConfig {
    let mut cfg = AiConfig::default();

    if let Some(path) = local_config_path() {
        if let Ok(text) = fs::read_to_string(&path) {
            if let Ok(file_cfg) = serde_json::from_str::<AiConfigFile>(&text) {
                merge_file(&mut cfg, file_cfg);
            }
        }
    }

    if let Some(path) = home_config_path() {
        if let Ok(text) = fs::read_to_string(&path) {
            if let Ok(file_cfg) = serde_json::from_str::<AiConfigFile>(&text) {
                merge_file(&mut cfg, file_cfg);
            }
        }
    }

    if let Ok(k) = env::var("DEEPSEEK_API_KEY") {
        if !k.trim().is_empty() {
            cfg.api_key = Some(k.trim().to_string());
        }
    }
    if let Ok(b) = env::var("DEEPSEEK_BASE_URL") {
        if !b.trim().is_empty() {
            cfg.base_url = b.trim().trim_end_matches('/').to_string();
        }
    }
    if let Ok(m) = env::var("DEEPSEEK_MODEL") {
        if !m.trim().is_empty() {
            cfg.model = m.trim().to_string();
        }
    }

    cfg
}

#[derive(Debug, Deserialize)]
struct AiConfigFile {
    api_key: Option<String>,
    deepseek_api_key: Option<String>,
    base_url: Option<String>,
    model: Option<String>,
    thinking: Option<bool>,
}

fn merge_file(cfg: &mut AiConfig, file: AiConfigFile) {
    if let Some(k) = file.api_key.or(file.deepseek_api_key) {
        if !k.trim().is_empty() {
            cfg.api_key = Some(k.trim().to_string());
        }
    }
    if let Some(b) = file.base_url {
        if !b.trim().is_empty() {
            cfg.base_url = b.trim().trim_end_matches('/').to_string();
        }
    }
    if let Some(m) = file.model {
        if !m.trim().is_empty() {
            cfg.model = m.trim().to_string();
        }
    }
    if let Some(t) = file.thinking {
        cfg.thinking = t;
    }
}

fn local_config_path() -> Option<PathBuf> {
    let candidates = [
        PathBuf::from(".portless.local.json"),
        PathBuf::from("../.portless.local.json"),
        PathBuf::from("../../.portless.local.json"),
    ];
    if let Ok(exe) = env::current_exe() {
        if let Some(dir) = exe.parent() {
            let p = dir.join(".portless.local.json");
            if p.exists() {
                return Some(p);
            }
            let p2 = dir
                .join("../../../.portless.local.json")
                .canonicalize()
                .ok();
            if let Some(p2) = p2 {
                if p2.exists() {
                    return Some(p2);
                }
            }
        }
    }
    for c in candidates {
        if c.exists() {
            return Some(c);
        }
    }
    None
}

fn home_config_path() -> Option<PathBuf> {
    let home = env::var_os("HOME").or_else(|| env::var_os("USERPROFILE"))?;
    Some(PathBuf::from(home).join(".portless").join("config.json"))
}

pub fn status() -> AiStatus {
    let cfg = load_config();
    let key_hint = cfg.api_key.as_ref().map(|k| {
        if k.len() <= 10 {
            "sk-****".into()
        } else {
            format!("{}…{}", &k[..6], &k[k.len().saturating_sub(4)..])
        }
    });
    AiStatus {
        configured: cfg.api_key.as_ref().map(|k| !k.is_empty()).unwrap_or(false),
        model: cfg.model,
        base_url: cfg.base_url,
        key_hint,
    }
}

/// Explain a single port/process; always returns structured `data` on success.
pub fn explain_process(item: &PortProcess, model_override: Option<&str>) -> ExplainResult {
    let cfg = load_config();
    let Some(api_key) = cfg.api_key.filter(|k| !k.is_empty()) else {
        return ExplainResult {
            ok: false,
            model: cfg.model,
            summary: String::new(),
            raw: String::new(),
            data: None,
            message: Some(
                "未配置 DeepSeek API Key。请设置环境变量 DEEPSEEK_API_KEY，或写入 .portless.local.json"
                    .into(),
            ),
        };
    };

    let model = model_override
        .map(|s| s.to_string())
        .unwrap_or(cfg.model.clone());

    let user_prompt = build_prompt(item);
    match chat_completion_json(&cfg.base_url, &api_key, &model, cfg.thinking, &user_prompt) {
        Ok(raw) => match parse_insight(&raw) {
            Ok(insight) => {
                let insight = insight.normalize();
                let summary = insight.to_summary_text();
                ExplainResult {
                    ok: true,
                    model,
                    summary,
                    raw,
                    data: Some(insight),
                    message: None,
                }
            }
            Err(e) => ExplainResult {
                ok: false,
                model,
                summary: String::new(),
                raw,
                data: None,
                message: Some(format!("结构化解析失败: {e}")),
            },
        },
        Err(e) => ExplainResult {
            ok: false,
            model,
            summary: String::new(),
            raw: String::new(),
            data: None,
            message: Some(e),
        },
    }
}

fn parse_insight(raw: &str) -> Result<ProcessInsight, String> {
    let text = strip_code_fence(raw.trim());
    // Direct parse
    if let Ok(v) = serde_json::from_str::<ProcessInsight>(text) {
        return Ok(v);
    }
    // Maybe wrapped: { "insight": {...} } or extra keys
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(text) {
        // Try common wrappers
        for key in ["data", "insight", "result", "analysis"] {
            if let Some(inner) = v.get(key) {
                if let Ok(p) = serde_json::from_value::<ProcessInsight>(inner.clone()) {
                    return Ok(p);
                }
            }
        }
        // Lenient map from partial fields
        if let Ok(p) = serde_json::from_value::<ProcessInsightLoose>(v.clone()) {
            return Ok(p.into_insight());
        }
        return Err(format!(
            "JSON 字段不符合 schema: {}",
            text.chars().take(200).collect::<String>()
        ));
    }
    Err("模型未返回合法 JSON".into())
}

/// Accept alternate key names / missing fields from the model.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ProcessInsightLoose {
    #[serde(default)]
    headline: Option<String>,
    #[serde(alias = "summary", alias = "conclusion")]
    one_line: Option<String>,
    #[serde(default)]
    service_name: Option<String>,
    #[serde(alias = "name")]
    service: Option<String>,
    #[serde(default)]
    category: Option<String>,
    #[serde(default)]
    stack: Option<String>,
    #[serde(alias = "tech_stack", alias = "technology")]
    tech: Option<String>,
    #[serde(default)]
    purpose: Option<String>,
    #[serde(alias = "usage", alias = "scenario")]
    use_case: Option<String>,
    #[serde(default)]
    is_dev_service: Option<bool>,
    #[serde(default, alias = "kill_advice")]
    stop_advice: Option<String>,
    #[serde(default)]
    stop_impact: Option<String>,
    #[serde(default)]
    confidence: Option<f32>,
    #[serde(default, alias = "suggestions", alias = "recommendations")]
    actions: Option<Vec<String>>,
    #[serde(default)]
    risks: Option<Vec<String>>,
    #[serde(default)]
    notes: Option<String>,
}

impl ProcessInsightLoose {
    fn into_insight(self) -> ProcessInsight {
        ProcessInsight {
            headline: self
                .headline
                .or(self.one_line)
                .unwrap_or_else(|| "未知服务".into()),
            service_name: self
                .service_name
                .or(self.service)
                .unwrap_or_else(|| "Unknown".into()),
            category: self.category.unwrap_or_else(|| "unknown".into()),
            stack: self.stack.or(self.tech).unwrap_or_else(|| "未知".into()),
            purpose: self
                .purpose
                .or(self.use_case)
                .unwrap_or_else(|| "未知".into()),
            is_dev_service: self.is_dev_service.unwrap_or(false),
            stop_advice: self.stop_advice.unwrap_or_else(|| "caution".into()),
            stop_impact: self.stop_impact.unwrap_or_else(|| "未知".into()),
            confidence: self.confidence.unwrap_or(0.5),
            actions: self.actions.unwrap_or_default(),
            risks: self.risks.unwrap_or_default(),
            notes: self.notes.unwrap_or_default(),
        }
    }
}

fn strip_code_fence(s: &str) -> &str {
    let s = s.trim();
    if let Some(rest) = s.strip_prefix("```json") {
        if let Some(end) = rest.rfind("```") {
            return rest[..end].trim();
        }
    }
    if let Some(rest) = s.strip_prefix("```") {
        if let Some(end) = rest.rfind("```") {
            return rest[..end].trim();
        }
    }
    s
}

fn build_prompt(p: &PortProcess) -> String {
    format!(
        r#"你是 Portless 的进程解读引擎。根据下面的本机监听端口/进程快照，输出**唯一**一个 JSON 对象。

硬性要求：
1. 只输出 JSON，不要 Markdown，不要代码围栏，不要额外解释。
2. 字段名与类型必须完全匹配 schema。
3. 不要编造不存在的信息；不确定时用「未知」，confidence 调低。
4. stopAdvice 只能是: "safe" | "caution" | "do_not"
5. category 只能是: "dev" | "system" | "database" | "proxy" | "runtime" | "unknown"
6. actions 1~3 条，短句、可操作；risks 0~3 条。

JSON schema（全部字段必填）：
{{
  "headline": "string — 一句话结论",
  "serviceName": "string — 服务展示名",
  "category": "dev|system|database|proxy|runtime|unknown",
  "stack": "string — 技术栈",
  "purpose": "string — 用途与场景",
  "isDevService": true,
  "stopAdvice": "safe|caution|do_not",
  "stopImpact": "string — 停止影响",
  "confidence": 0.0,
  "actions": ["string"],
  "risks": ["string"],
  "notes": "string — 补充或未知项说明"
}}

--- 进程快照 ---
端口: {port}
协议: {protocol}
地址: {address}
状态: {state:?}
PID: {pid}
进程名: {process_name}
技术栈识别: {stack}
是否开发服务(启发式): {is_dev}
项目名: {project}
可执行文件: {exe}
工作目录: {cwd}
命令行: {cmd}
CPU: {cpu}
内存(bytes): {mem}
"#,
        port = p.port,
        protocol = p.protocol,
        address = p.address,
        state = p.state,
        pid = p.pid,
        process_name = p.process_name,
        stack = p.stack.as_deref().unwrap_or("—"),
        is_dev = p.is_dev,
        project = p.project_name.as_deref().unwrap_or("—"),
        exe = p.executable_path.as_deref().unwrap_or("—"),
        cwd = p.working_directory.as_deref().unwrap_or("—"),
        cmd = p.command_line.as_deref().unwrap_or("—"),
        cpu = p
            .cpu_usage
            .map(|c| format!("{c:.1}%"))
            .unwrap_or_else(|| "—".into()),
        mem = p
            .memory_usage
            .map(|m| m.to_string())
            .unwrap_or_else(|| "—".into()),
    )
}

fn chat_completion_json(
    base_url: &str,
    api_key: &str,
    model: &str,
    thinking: bool,
    user_prompt: &str,
) -> Result<String, String> {
    let url = format!("{}/chat/completions", base_url.trim_end_matches('/'));

    let mut body = serde_json::json!({
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": "You are Portless's structured process analyzer. Always respond with a single valid JSON object matching the requested schema. No markdown."
            },
            {
                "role": "user",
                "content": user_prompt
            }
        ],
        "stream": false,
        "temperature": 0.2,
        // DeepSeek JSON Output mode
        "response_format": { "type": "json_object" }
    });

    if thinking {
        body["thinking"] = serde_json::json!({"type": "enabled"});
        body["reasoning_effort"] = serde_json::json!("high");
    }

    let agent = ureq::Agent::config_builder()
        .timeout_global(Some(std::time::Duration::from_secs(90)))
        .build()
        .new_agent();

    let response = agent
        .post(&url)
        .header("Authorization", &format!("Bearer {api_key}"))
        .header("Content-Type", "application/json")
        .send_json(&body)
        .map_err(|e| format!("DeepSeek 请求失败: {e}"))?;

    let status = response.status();
    let value: serde_json::Value = response
        .into_body()
        .read_json()
        .map_err(|e| format!("解析 DeepSeek 响应失败: {e}"))?;

    if !status.is_success() {
        let msg = value
            .pointer("/error/message")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown error");
        return Err(format!("DeepSeek HTTP {status}: {msg}"));
    }

    let content = value
        .pointer("/choices/0/message/content")
        .and_then(|v| {
            if let Some(s) = v.as_str() {
                Some(s.to_string())
            } else if v.is_array() {
                let parts: Vec<String> = v
                    .as_array()
                    .unwrap_or(&vec![])
                    .iter()
                    .filter_map(|p| p.get("text").and_then(|t| t.as_str()).map(|s| s.to_string()))
                    .collect();
                if parts.is_empty() {
                    None
                } else {
                    Some(parts.join("\n"))
                }
            } else {
                None
            }
        })
        .filter(|s| !s.trim().is_empty());

    content.ok_or_else(|| {
        format!(
            "DeepSeek 返回空内容: {}",
            value.to_string().chars().take(400).collect::<String>()
        )
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_stop_and_category() {
        let i = ProcessInsight {
            headline: "  x  ".into(),
            service_name: "".into(),
            category: "Development".into(),
            stack: "Node".into(),
            purpose: "local".into(),
            is_dev_service: true,
            stop_advice: "可停".into(),
            stop_impact: "none".into(),
            confidence: 1.5,
            actions: vec![],
            risks: vec![],
            notes: "".into(),
        }
        .normalize();
        assert_eq!(i.category, "dev");
        assert_eq!(i.stop_advice, "safe");
        assert_eq!(i.confidence, 1.0);
        assert!(!i.actions.is_empty());
        assert_eq!(i.service_name, "Unknown");
    }

    #[test]
    fn parses_json_insight() {
        let raw = r#"{
          "headline":"本地 Node 服务",
          "serviceName":"Node.js",
          "category":"dev",
          "stack":"Node.js",
          "purpose":"开发调试",
          "isDevService":true,
          "stopAdvice":"caution",
          "stopImpact":"中断本地服务",
          "confidence":0.8,
          "actions":["查看命令行"],
          "risks":[],
          "notes":""
        }"#;
        let p = parse_insight(raw).unwrap().normalize();
        assert_eq!(p.service_name, "Node.js");
        assert_eq!(p.stop_advice, "caution");
    }
}
