#!/usr/bin/env python3
"""Generate project.pbxproj and shared scheme for NotchBlock and NotchBlockTests."""

import hashlib
import os


def make_id(seed: str) -> str:
    """Deterministic 24-char hex ID from a seed string."""
    return hashlib.sha256(seed.encode()).hexdigest()[:24].upper()


# ── Source & Resource Lists ──────────────────────────────────────
app_files = [
    ("NotchBlockApp.swift",              "NotchBlock/NotchBlockApp.swift"),
    ("TimeBlock.swift",                  "NotchBlock/Models/TimeBlock.swift"),
    ("BlockStatus.swift",                "NotchBlock/Models/BlockStatus.swift"),
    ("TimeBlockStore.swift",             "NotchBlock/Managers/TimeBlockStore.swift"),
    ("NotchTracker.swift",               "NotchBlock/Managers/NotchTracker.swift"),
    ("NotchPanelController.swift",       "NotchBlock/Managers/NotchPanelController.swift"),
    ("OverlayWindowController.swift",    "NotchBlock/Managers/OverlayWindowController.swift"),
    ("OnboardingWindowController.swift", "NotchBlock/Managers/OnboardingWindowController.swift"),
    ("MainWindowController.swift",       "NotchBlock/Managers/MainWindowController.swift"),
    ("BlockScheduler.swift",             "NotchBlock/Managers/BlockScheduler.swift"),
    ("BreakScheduler.swift",             "NotchBlock/Managers/BreakScheduler.swift"),
    ("WeChatNotifier.swift",             "NotchBlock/Managers/WeChatNotifier.swift"),
    ("StatisticsStore.swift",            "NotchBlock/Managers/StatisticsStore.swift"),
    ("MainSchedulerView.swift",          "NotchBlock/Views/MainSchedulerView.swift"),
    ("TimeBlockRowView.swift",           "NotchBlock/Views/TimeBlockRowView.swift"),
    ("AddEditBlockView.swift",           "NotchBlock/Views/AddEditBlockView.swift"),
    ("NotchPanelView.swift",             "NotchBlock/Views/NotchPanelView.swift"),
    ("OverlayView.swift",                "NotchBlock/Views/OverlayView.swift"),
    ("WeChatSettingsView.swift",         "NotchBlock/Views/WeChatSettingsView.swift"),
    ("StatisticsView.swift",             "NotchBlock/Views/StatisticsView.swift"),
    ("OnboardingView.swift",             "NotchBlock/Views/OnboardingView.swift"),
    ("ScheduleTimelineView.swift",       "NotchBlock/Views/ScheduleTimelineView.swift"),
    ("MenuBarIconView.swift",            "NotchBlock/Views/MenuBarIconView.swift"),
    ("MenuBarPopoverView.swift",         "NotchBlock/Views/MenuBarPopoverView.swift"),
    ("SettingsView.swift",               "NotchBlock/Views/SettingsView.swift"),
    ("WhatsNewView.swift",               "NotchBlock/Views/WhatsNewView.swift"),
    ("MinimalComponents.swift",          "NotchBlock/Views/MinimalComponents.swift"),
    ("DateExtensions.swift",             "NotchBlock/Utilities/DateExtensions.swift"),
    ("LaunchManager.swift",              "NotchBlock/Utilities/LaunchManager.swift"),
    ("BrandColors.swift",                "NotchBlock/Utilities/BrandColors.swift"),
    ("UpdateChecker.swift",              "NotchBlock/Utilities/UpdateChecker.swift"),
    ("NSScreen+Notch.swift",             "NotchBlock/Utilities/NSScreen+Notch.swift"),
]

test_files = [
    ("TimeBlockTests.swift",     "Tests/TimeBlockTests.swift"),
    ("StatisticsTests.swift",    "Tests/StatisticsTests.swift"),
    ("UpdateCheckerTests.swift", "Tests/UpdateCheckerTests.swift"),
    ("UIThemeTests.swift",       "Tests/UIThemeTests.swift"),
]

resources = [
    ("Assets",    "NotchBlock/Resources/Assets.xcassets"),
    ("CHANGELOG", "CHANGELOG.md"),
]

# ── UUID Generation ──────────────────────────────────────────────
proj_id        = make_id("PBXProject")
root_group     = make_id("rootGroup")
main_group     = make_id("mainGroup")
models_grp     = make_id("modelsGroup")
managers_grp   = make_id("managersGroup")
views_grp      = make_id("viewsGroup")
utils_grp      = make_id("utilsGroup")
resources_grp  = make_id("resourcesGroup")
tests_grp      = make_id("testsGroup")
products_grp   = make_id("productsGroup")

target_id      = make_id("nativeTarget")
tests_target_id = make_id("testsTarget")
product_ref    = make_id("productRef")
tests_product_ref = make_id("testsProductRef")
proxy_id       = make_id("containerItemProxy")
dep_id         = make_id("targetDependency")

proj_cfg_list  = make_id("buildConfigList_project")
app_cfg_list   = make_id("buildConfigList_target")
tests_cfg_list = make_id("buildConfigList_tests")

dbg_proj       = make_id("debugConfig_project")
rel_proj       = make_id("releaseConfig_project")
dbg_tgt        = make_id("debugConfig_target")
rel_tgt        = make_id("releaseConfig_target")
dbg_tests      = make_id("debugConfig_tests")
rel_tests      = make_id("releaseConfig_tests")

src_phase      = make_id("sourcesBuildPhase")
res_phase      = make_id("resourcesBuildPhase")
tests_src_phase = make_id("testsSourcesBuildPhase")

file_ref_ids = {}
build_file_ids = {}
for name, _ in app_files + test_files + resources:
    file_ref_ids[name] = make_id(f"fileRef:{name}")
    build_file_ids[name] = make_id(f"buildFile:{name}")

info_plist_name = "Info.plist"
info_plist_ref  = make_id(f"fileRef:{info_plist_name}")
file_ref_ids[info_plist_name] = info_plist_ref


# ── Sections ─────────────────────────────────────────────────────

def build_files_section():
    lines = []
    for name, _ in app_files + test_files + resources:
        lines.append(f'\t\t{build_file_ids[name]} /* {name} */ = {{isa = PBXBuildFile; fileRef = {file_ref_ids[name]} /* {name} */; }};')
    return "\n".join(lines)


def file_refs_section():
    lines = []
    for name, _ in app_files + test_files:
        lines.append(f'\t\t{file_ref_ids[name]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = "<group>"; }};')
    lines.append(f'\t\t{file_ref_ids["Assets"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "Assets.xcassets"; sourceTree = "<group>"; }};')
    lines.append(f'\t\t{file_ref_ids["CHANGELOG"]} /* CHANGELOG.md */ = {{isa = PBXFileReference; lastKnownFileType = net.daringfireball.markdown; path = "CHANGELOG.md"; sourceTree = SOURCE_ROOT; }};')
    lines.append(f'\t\t{info_plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info.plist"; sourceTree = "<group>"; }};')
    lines.append(f'\t\t{product_ref} /* NotchBlock.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = NotchBlock.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    lines.append(f'\t\t{tests_product_ref} /* NotchBlockTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = NotchBlockTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
    return "\n".join(lines)


def groups_section():
    def children(names):
        return "\n".join(f"\t\t\t\t{file_ref_ids[n]} /* {n} */," for n in names)

    return f"""\t\t{root_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{main_group} /* NotchBlock */,
\t\t\t\t{tests_grp} /* Tests */,
\t\t\t\t{file_ref_ids['CHANGELOG']} /* CHANGELOG.md */,
\t\t\t\t{products_grp} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_ids['NotchBlockApp.swift']} /* NotchBlockApp.swift */,
\t\t\t\t{info_plist_ref} /* Info.plist */,
\t\t\t\t{models_grp} /* Models */,
\t\t\t\t{managers_grp} /* Managers */,
\t\t\t\t{views_grp} /* Views */,
\t\t\t\t{utils_grp} /* Utilities */,
\t\t\t\t{resources_grp} /* Resources */,
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
{children(['TimeBlockStore.swift', 'NotchTracker.swift', 'NotchPanelController.swift', 'OverlayWindowController.swift', 'OnboardingWindowController.swift', 'MainWindowController.swift', 'BlockScheduler.swift', 'BreakScheduler.swift', 'WeChatNotifier.swift', 'StatisticsStore.swift'])}
\t\t\t);
\t\t\tpath = Managers;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{views_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(['MainSchedulerView.swift', 'TimeBlockRowView.swift', 'AddEditBlockView.swift', 'NotchPanelView.swift', 'OverlayView.swift', 'WeChatSettingsView.swift', 'StatisticsView.swift', 'OnboardingView.swift', 'ScheduleTimelineView.swift', 'MenuBarIconView.swift', 'MenuBarPopoverView.swift', 'SettingsView.swift', 'WhatsNewView.swift', 'MinimalComponents.swift'])}
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{utils_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(['DateExtensions.swift', 'LaunchManager.swift', 'BrandColors.swift', 'UpdateChecker.swift', 'NSScreen+Notch.swift'])}
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
\t\t{tests_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children([n for n, _ in test_files])}
\t\t\t);
\t\t\tpath = Tests;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{products_grp} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{product_ref} /* NotchBlock.app */,
\t\t\t\t{tests_product_ref} /* NotchBlockTests.xctest */,
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


# ── Build Settings ───────────────────────────────────────────────

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
    "SDKROOT": "macosx",
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
    "SDKROOT": "macosx",
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
    "MARKETING_VERSION": "0.7.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.notchblock.app",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "6.0",
}

TESTS_COMMON = {
    "BUNDLE_LOADER": "$(TEST_HOST)",
    "CODE_SIGN_STYLE": "Automatic",
    "GENERATE_INFOPLIST_FILE": "YES",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks", "@loader_path/../Frameworks"],
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.notchblock.app.tests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_VERSION": "6.0",
    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/NotchBlock.app/Contents/MacOS/NotchBlock",
}

# ── Source/Resource File Lists ───────────────────────────────────

src_files_block = "\n".join(
    f"\t\t\t\t{build_file_ids[n]} /* {n} in Sources */,"
    for n, _ in app_files
)

tests_src_files_block = "\n".join(
    f"\t\t\t\t{build_file_ids[n]} /* {n} in Sources */,"
    for n, _ in test_files
)

res_files_block = "\n".join(
    f"\t\t\t\t{build_file_ids[n]} /* {n} in Resources */,"
    for n, _ in resources
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

/* Begin PBXContainerItemProxy section */
\t\t{proxy_id} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {proj_id} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {target_id};
\t\t\tremoteInfo = NotchBlock;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
{file_refs_section()}
/* End PBXFileReference section */

/* Begin PBXGroup section */
{groups_section()}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* NotchBlock */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {app_cfg_list} /* Build configuration list for PBXNativeTarget "NotchBlock" */;
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
\t\t{tests_target_id} /* NotchBlockTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {tests_cfg_list} /* Build configuration list for PBXNativeTarget "NotchBlockTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{tests_src_phase} /* Sources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{dep_id} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = NotchBlockTests;
\t\t\tproductName = NotchBlockTests;
\t\t\tproductReference = {tests_product_ref} /* NotchBlockTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
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
\t\t\t\t\t{tests_target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.4;
\t\t\t\t\t\tTestTargetID = {target_id};
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject "NotchBlock" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = "zh-Hans";
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t\t"zh-Hans",
\t\t\t);
\t\t\tmainGroup = {root_group};
\t\t\tproductRefGroup = {products_grp} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_id} /* NotchBlock */,
\t\t\t\t{tests_target_id} /* NotchBlockTests */,
\t\t\t);
\t\t}};
/* End PBXProject section */

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

/* Begin PBXSourcesBuildPhase section */
\t\t{src_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{src_files_block}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{tests_src_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{tests_src_files_block}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
\t\t{dep_id} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {target_id} /* NotchBlock */;
\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

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
\t\t{dbg_tests} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{build_settings(TESTS_COMMON)}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{rel_tests} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{build_settings(TESTS_COMMON)}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{proj_cfg_list} /* Build configuration list for PBXProject "NotchBlock" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{dbg_proj} /* Debug */,
\t\t\t\t{rel_proj} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{app_cfg_list} /* Build configuration list for PBXNativeTarget "NotchBlock" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{dbg_tgt} /* Debug */,
\t\t\t\t{rel_tgt} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{tests_cfg_list} /* Build configuration list for PBXNativeTarget "NotchBlockTests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{dbg_tests} /* Debug */,
\t\t\t\t{rel_tests} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {proj_id} /* Project object */;
}}
"""

xcscheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1640"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "NotchBlock.app"
               BlueprintName = "NotchBlock"
               ReferencedContainer = "container:NotchBlock.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tests_target_id}"
               BuildableName = "NotchBlockTests.xctest"
               BlueprintName = "NotchBlockTests"
               ReferencedContainer = "container:NotchBlock.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "NotchBlock.app"
            BlueprintName = "NotchBlock"
            ReferencedContainer = "container:NotchBlock.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "NotchBlock.app"
            BlueprintName = "NotchBlock"
            ReferencedContainer = "container:NotchBlock.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

xcodeproj_dir = "NotchBlock.xcodeproj"
schemes_dir = os.path.join(xcodeproj_dir, "xcshareddata", "xcschemes")
os.makedirs(schemes_dir, exist_ok=True)

pbxproj_path = os.path.join(xcodeproj_dir, "project.pbxproj")
with open(pbxproj_path, "w") as f:
    f.write(pbxproj)

scheme_path = os.path.join(schemes_dir, "NotchBlock.xcscheme")
with open(scheme_path, "w") as f:
    f.write(xcscheme)

print(f"✅ Written {pbxproj_path} ({len(pbxproj)} bytes) and {scheme_path}")
