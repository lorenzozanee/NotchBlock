#!/usr/bin/env python3
"""Generate a minimal but valid project.pbxproj for NotchBlock macOS app."""

import hashlib
import os

def make_id(seed: str) -> str:
    """Deterministic 24-char hex ID from a seed string."""
    return hashlib.sha256(seed.encode()).hexdigest()[:24].upper()

# ── Source files ─────────────────────────────────────────────────
files = [
    ("NotchBlockApp.swift",         "NotchBlock/NotchBlockApp.swift"),
    ("TimeBlock.swift",             "NotchBlock/Models/TimeBlock.swift"),
    ("BlockStatus.swift",           "NotchBlock/Models/BlockStatus.swift"),
    ("TimeBlockStore.swift",        "NotchBlock/Managers/TimeBlockStore.swift"),
    ("NotchTracker.swift",          "NotchBlock/Managers/NotchTracker.swift"),
    ("NotchPanelController.swift",  "NotchBlock/Managers/NotchPanelController.swift"),
    ("OverlayWindowController.swift","NotchBlock/Managers/OverlayWindowController.swift"),
    ("OnboardingWindowController.swift","NotchBlock/Managers/OnboardingWindowController.swift"),
    ("BlockScheduler.swift",        "NotchBlock/Managers/BlockScheduler.swift"),
    ("BreakScheduler.swift",        "NotchBlock/Managers/BreakScheduler.swift"),
    ("WeChatNotifier.swift",        "NotchBlock/Managers/WeChatNotifier.swift"),
    ("StatisticsStore.swift",       "NotchBlock/Managers/StatisticsStore.swift"),
    ("MainSchedulerView.swift",     "NotchBlock/Views/MainSchedulerView.swift"),
    ("TimeBlockRowView.swift",      "NotchBlock/Views/TimeBlockRowView.swift"),
    ("AddEditBlockView.swift",      "NotchBlock/Views/AddEditBlockView.swift"),
    ("NotchPanelView.swift",        "NotchBlock/Views/NotchPanelView.swift"),
    ("OverlayView.swift",           "NotchBlock/Views/OverlayView.swift"),
    ("WeChatSettingsView.swift",    "NotchBlock/Views/WeChatSettingsView.swift"),
    ("StatisticsView.swift",        "NotchBlock/Views/StatisticsView.swift"),
    ("OnboardingView.swift",        "NotchBlock/Views/OnboardingView.swift"),
    ("TimelineView.swift",          "NotchBlock/Views/TimelineView.swift"),
    ("MenuBarIconView.swift",       "NotchBlock/Views/MenuBarIconView.swift"),
    ("WhatsNewView.swift",          "NotchBlock/Views/WhatsNewView.swift"),
    ("DateExtensions.swift",        "NotchBlock/Utilities/DateExtensions.swift"),
    ("LaunchManager.swift",         "NotchBlock/Utilities/LaunchManager.swift"),
    ("BrandColors.swift",           "NotchBlock/Utilities/BrandColors.swift"),
    ("UpdateChecker.swift",         "NotchBlock/Utilities/UpdateChecker.swift"),
]

resources = [
    ("Assets", "NotchBlock/Resources/Assets.xcassets"),
    ("CHANGELOG", "CHANGELOG.md"),
]

# ── UUID generation ──────────────────────────────────────────────
proj_id      = make_id("PBXProject")
main_group   = make_id("mainGroup")
models_grp   = make_id("modelsGroup")
managers_grp = make_id("managersGroup")
views_grp    = make_id("viewsGroup")
utils_grp    = make_id("utilsGroup")
resources_grp= make_id("resourcesGroup")
products_grp = make_id("productsGroup")
target_id    = make_id("nativeTarget")
product_ref  = make_id("productRef")
dbg_list     = make_id("buildConfigList_project")
rel_list     = make_id("buildConfigList_target")
dbg_proj     = make_id("debugConfig_project")
rel_proj     = make_id("releaseConfig_project")
dbg_tgt      = make_id("debugConfig_target")
rel_tgt      = make_id("releaseConfig_target")
src_phase    = make_id("sourcesBuildPhase")
res_phase    = make_id("resourcesBuildPhase")

file_ref_ids = {}
build_file_ids = {}
for name, _ in files + resources:
    file_ref_ids[name] = make_id(f"fileRef:{name}")
    build_file_ids[name] = make_id(f"buildFile:{name}")

# Info.plist is in the source root, not Resources/ — add manually
info_plist_name = "Info.plist"
info_plist_ref  = make_id(f"fileRef:{info_plist_name}")
info_plist_build = make_id(f"buildFile:{info_plist_name}")
file_ref_ids[info_plist_name] = info_plist_ref
build_file_ids[info_plist_name] = info_plist_build

# ── Sections ─────────────────────────────────────────────────────

def build_files_section():
    lines = []
    all_items = list(files) + list(resources) + [(info_plist_name, "NotchBlock/Info.plist")]
    for name, _ in all_items:
        lines.append(f'\t\t{build_file_ids[name]} /* {name} */ = {{isa = PBXBuildFile; fileRef = {file_ref_ids[name]} /* {name} */; }};')
    return "\n".join(lines)

def file_refs_section():
    lines = []
    for name, _ in files:
        lines.append(f'\t\t{file_ref_ids[name]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = "<group>"; }};')
    # Assets
    lines.append(f'\t\t{file_ref_ids["Assets"]} /* Assets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "Assets.xcassets"; sourceTree = "<group>"; }};')
    # Info.plist (at source root, not in Resources/)
    lines.append(f'\t\t{info_plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info.plist"; sourceTree = "<group>"; }};')
    # Product
    lines.append(f'\t\t{product_ref} /* NotchBlock.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = NotchBlock.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    return "\n".join(lines)

def groups_section():
    def children(names):
        return "\n".join(f"\t\t\t\t{file_ref_ids[n]} /* {n} */," for n in names)

    return f"""\t\t{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_ids['NotchBlockApp.swift']} /* NotchBlockApp.swift */,
\t\t\t\t{info_plist_ref} /* Info.plist */,
\t\t\t\t{models_grp} /* Models */,
\t\t\t\t{managers_grp} /* Managers */,
\t\t\t\t{views_grp} /* Views */,
\t\t\t\t{utils_grp} /* Utilities */,
\t\t\t\t{resources_grp} /* Resources */,
\t\t\t\t{products_grp} /* Products */,
\t\t\t);
\t\t\tpath = "NotchBlock";
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{models_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(['TimeBlock.swift', 'BlockStatus.swift'])}
\t\t\t);
\t\t\tpath = Models;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{managers_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(['TimeBlockStore.swift', 'NotchTracker.swift', 'NotchPanelController.swift', 'OverlayWindowController.swift', 'OnboardingWindowController.swift', 'BlockScheduler.swift', 'BreakScheduler.swift', 'WeChatNotifier.swift', 'StatisticsStore.swift'])}
\t\t\t);
\t\t\tpath = Managers;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{views_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(['MainSchedulerView.swift', 'TimeBlockRowView.swift', 'AddEditBlockView.swift', 'NotchPanelView.swift', 'OverlayView.swift', 'WeChatSettingsView.swift', 'StatisticsView.swift', 'OnboardingView.swift', 'TimelineView.swift', 'MenuBarIconView.swift', 'WhatsNewView.swift'])}
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{utils_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(['DateExtensions.swift', 'LaunchManager.swift', 'BrandColors.swift', 'UpdateChecker.swift'])}
\t\t\t);
\t\t\tpath = Utilities;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{resources_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(['Assets'])}
\t\t\t);
\t\t\tpath = Resources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{products_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{product_ref} /* NotchBlock.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};"""

def build_settings(settings_dict):
    """Format a dict of build settings for pbxproj."""
    lines = []
    for k, v in settings_dict.items():
        if isinstance(v, list):
            vals = ",\n".join(f'\t\t\t\t\t"{x}"' for x in v)
            lines.append(f"\t\t\t\t{k} = (\n{vals}\n\t\t\t\t);")
        elif v is True:
            lines.append(f"\t\t\t\t{k} = YES;")
        elif v is False:
            lines.append(f"\t\t\t\t{k} = NO;")
        else:
            lines.append(f'\t\t\t\t{k} = "{v}";')
    return "\n".join(lines)

# ── Build settings ───────────────────────────────────────────────

PROJECT_DEBUG = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}

PROJECT_RELEASE = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_OPTIMIZATION_LEVEL": "s",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
}

TARGET_COMMON = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "ENABLE_HARDENED_RUNTIME": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "NotchBlock/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks"],
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.notchblock.app",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
}

# ── Source/Resource file lists ──────────────────────────────────

src_files_block = "\n".join(
    f"\t\t\t\t{build_file_ids[n]} /* {n} in Sources */,"
    for n, _ in files
)

res_files_block = "\n".join(
    f"\t\t\t\t{build_file_ids[n]} /* {n} in Resources */,"
    for n in ["Assets"]  # Info.plist handled via INFOPLIST_FILE, not Copy Bundle Resources
)

# ── Full pbxproj ─────────────────────────────────────────────────

pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_files_section()}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs_section()}
/* End PBXFileReference section */

/* Begin PBXGroup section */
{groups_section()}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* NotchBlock */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {rel_list} /* Build configuration list for PBXNativeTarget "NotchBlock" */;
\t\t\tbuildPhases = (
\t\t\t\t{src_phase} /* Sources */,
\t\t\t\t{res_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = NotchBlock;
\t\t\tproductName = NotchBlock;
\t\t\tproductReference = {product_ref} /* NotchBlock.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{proj_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1640;
\t\t\t\tLastUpgradeCheck = 1640;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.4;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {dbg_list} /* Build configuration list for PBXProject "NotchBlock" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = "zh-Hans";
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t\t"zh-Hans",
\t\t\t);
\t\t\tmainGroup = {main_group};
\t\t\tproductRefGroup = {products_grp} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_id} /* NotchBlock */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
\t\t{src_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{src_files_block}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXResourcesBuildPhase section */
\t\t{res_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{res_files_block}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{dbg_proj} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{build_settings(PROJECT_DEBUG)}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{rel_proj} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{build_settings(PROJECT_RELEASE)}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{dbg_tgt} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{build_settings(TARGET_COMMON)}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{rel_tgt} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{build_settings(TARGET_COMMON)}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{dbg_list} /* Build configuration list for PBXProject "NotchBlock" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{dbg_proj} /* Debug */,
\t\t\t\t{rel_proj} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{rel_list} /* Build configuration list for PBXNativeTarget "NotchBlock" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{dbg_tgt} /* Debug */,
\t\t\t\t{rel_tgt} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {proj_id} /* Project object */;
}}
"""

# Write output
xcodeproj_dir = "NotchBlock.xcodeproj"
os.makedirs(xcodeproj_dir, exist_ok=True)
out_path = os.path.join(xcodeproj_dir, "project.pbxproj")
with open(out_path, "w") as f:
    f.write(pbxproj)
print(f"✅ Written {out_path} ({len(pbxproj)} bytes)")
