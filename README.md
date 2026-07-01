# Pixel 5 Custom Kernel Build

Automated kernel build for Pixel 5 (redfin) using GitHub Actions.

## Branches

- `main` — Pure kernel (no KSU/SUSFS), validates kernel boots
- `resukisu` — ReSukiSU + SUSFS + KPM integrated

## Workflow

1. Fork this repo
2. Go to Actions tab
3. Run workflow manually
4. Download artifacts (AnyKernel3.zip, Image.lz4-dtb, boot.img)

## Device

- Pixel 5 (redfin)
- Android 14 (UP1A.231105.001.B2)
- Kernel 4.19.278
- Source: android-msm-redbull-4.19-android13-qpr3
- Compiler: clang r416183b (12.0.5)
- Config: build_redbull-gki.sh (VINTF + ThinLTO + CFI)
