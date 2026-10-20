# Badges für die CurseForge-Beschreibung

Dieselben drei Badges wie in der `README.md` (Vorlage: Can't Play Forever): letzte Version, letzter Push, CI-Status. Die
Bilder laden von shields.io, die Links führen zum Repository. Je nach Editor als Markdown oder als HTML einfügen.

Markdown:

```markdown
[![latest](https://img.shields.io/github/v/release/N3zr0k/BugLab?include_prereleases&sort=date&label=latest)](https://github.com/N3zr0k/BugLab/releases) [![last push](https://img.shields.io/github/last-commit/N3zr0k/BugLab/main?label=last%20push)](https://github.com/N3zr0k/BugLab/commits/main) [![CI](https://img.shields.io/github/actions/workflow/status/N3zr0k/BugLab/ci.yml?branch=main&label=CI)](https://github.com/N3zr0k/BugLab/actions/workflows/ci.yml)
```

HTML (mit dem dunklen Header darüber; das Bild lädt von GitHub):

```html
<p align="center">
  <img src="https://raw.githubusercontent.com/N3zr0k/BugLab/main/documentation/assets/BugLab_Header_dunkel.png" alt="BugLab: Debugging Toolkit for WoW Forever">
</p>
<p align="center">
  <a href="https://github.com/N3zr0k/BugLab/releases"><img src="https://img.shields.io/github/v/release/N3zr0k/BugLab?include_prereleases&sort=date&label=latest" alt="latest"></a>
  <a href="https://github.com/N3zr0k/BugLab/commits/main"><img src="https://img.shields.io/github/last-commit/N3zr0k/BugLab/main?label=last%20push" alt="last push"></a>
  <a href="https://github.com/N3zr0k/BugLab/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/N3zr0k/BugLab/ci.yml?branch=main&label=CI" alt="CI"></a>
</p>
```
