# T00 baseline evidence

- date: 2026-10-30
- repo HEAD: 92ce0ba900792c0ea8c00f18bef13dba0e475c36
- chezmoi: chezmoi version v2.73.1, commit 41a618c046fc5f7bb47cfebcd485d022c9ed5eb8, built at 2026-10-11T16:46:14Z, built by Homebrew
- claude: 2.1.314 (Claude Code)
- codex: codex-cli 0.164.0
- opencode: opencode v2.2.0
- fixtures rendered OK (valid JSON): legacy-linux, legacy-darwin, legacy-windows, legacy-devcontainer
- all four renders identical after key sort; golden = tests/ai/golden/legacy.settings.json

## claude plugin list (host, informational)
```
 ❯ agent-toolkit@mmalyska-claude-plugins	 Version: 1.0.0
 ❯ android@mmalyska-claude-plugins	 Version: 0.1.0
 ❯ backend@mmalyska-claude-plugins	 Version: 1.0.0
 ❯ claude-md-management@claude-plugins-official	 Version: 1.0.0
 ❯ code-simplifier@claude-plugins-official	 Version: 1.0.0
 ❯ context7@claude-plugins-official	 Version: f8c5e7a1dcb7
 ❯ devcontainer@mmalyska-claude-plugins	 Version: 0.1.0
 ❯ development-lifecycle@mmalyska-claude-plugins	 Version: 1.1.0
 ❯ devops@mmalyska-claude-plugins	 Version: 1.0.0
 ❯ dotnet@mmalyska-claude-plugins	 Version: 1.0.0
 ❯ frontend@mmalyska-claude-plugins	 Version: 1.0.0
 ❯ git-workflows@mmalyska-claude-plugins	 Version: 1.2.0
 ❯ gopls-lsp@claude-plugins-official	 Version: 1.0.0
 ❯ personal-essentials@mmalyska-claude-plugins	 Version: 1.0.0
 ❯ renovate@mmalyska-claude-plugins	 Version: 0.1.0
 ❯ security@mmalyska-claude-plugins	 Version: 1.0.0
 ❯ superpowers@claude-plugins-official	 Version: 7.0.0
```

## codex plugin list (host, informational)
```
Marketplace `openai-curated-remote`
Remote catalog

PLUGIN                                                                    STATUS              VERSION                                             SOURCE
gmail@openai-curated-remote                                               installed, enabled  0.1.10                                              plugin_connector_1p_95d39881713c8191931482a62d6edff9
app-6a057d268ebc81919918d37eec718425@openai-curated-remote                not installed       2.0.3                                               plugin_asdk_app_6a057d268ebc81919918d37eec718425
google-drive@openai-curated-remote                                        not installed       0.1.22                                              plugin_connector_1p_ab21a553bfbc81919ea8fd1858e3ffa7
app-69a8f78087e081919e52cacacf00ff36@openai-curated-remote                not installed       3.2.1                                               plugin_asdk_app_69a8f78087e081919e52cacacf00ff36
app-6a83901dde988191b3f3cefdcc19acfa@openai-curated-remote                not installed       2.0.2                                               plugin_asdk_app_6a83901dde988191b3f3cefdcc19acfa
app-6a244fb509e481918985fee76373b0f9@openai-curated-remote                not installed       1.0.0                                               plugin_asdk_app_6a244fb509e481918985fee76373b0f9
github@openai-curated-remote                                              installed, enabled  0.1.13-77c10e110b37                                 plugin_connector_1p_1a69035c238881919c4190932b2df699
app-6a314a73f8ac819195b0d55e36b9c609@openai-curated-remote                not installed       2.8.0                                               plugin_asdk_app_6a314a73f8ac819195b0d55e36b9c609
windsor-ai@openai-curated-remote                                          not installed       4.0.8                                               plugin_asdk_app_694a52cfaa3c819192bea84eaa254968
app-6a75165ed2d8819182548553aa4cb6d5@openai-curated-remote                not installed       12.0.0                                              plugin_asdk_app_6a75165ed2d8819182548553aa4cb6d5
app-69f63e01766881919640f03b5e7912a5@openai-curated-remote                not installed       3.7.0                                               plugin_asdk_app_69f63e01766881919640f03b5e7912a5
granola@openai-curated-remote                                             not installed       1.0.0                                               plugin_asdk_app_697761cab6f48191b5ed345919a3ce8b
outlook-email@openai-curated-remote                                       not installed       0.1.8                                               plugin_connector_1p_6bcb5879c73c819196abc70016166099
app-6a5ae9736be0819199d06d61ac171080@openai-curated-remote                not installed       1.0.0                                               plugin_asdk_app_6a5ae9736be0819199d06d61ac171080
supabase@openai-curated-remote                                            not installed       1.0.0                                               plugin_asdk_app_69d3e5ee6a708191baa733f7b8931995
slack@openai-curated-remote                                               not installed       0.1.8                                               plugin_asdk_app_69a1d78e929881919bba0dbda1f6436d
```
