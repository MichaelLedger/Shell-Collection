#!/usr/bin/env ruby
# frozen_string_literal: true

# Check which new files in XXX submodule are not added to Xcode project
#
# Usage:
#     ruby scripts/sync_submodule_files.rb
#
# Features:
#     1. Scan all source files in XXX directory
#     2. Check which files are not in Xcode project
#     3. List all new files not added
#     4. Automatically add new files to Xcode project

# %pwd
# XXX/scripts
# %ls
# check_resources.rb    FetchPreferences      FirebaseCrashlytics   removeFont.py         resources.txt         strip-frameworks.sh   sync_submodule_files.rb
# %ruby sync_submodule_files.rb

require 'xcodeproj'
require 'pathname'
require 'fileutils'
require 'set'

# Project root directory
PROJECT_ROOT = Pathname.new(__FILE__).parent.parent
PROJECT_FILE = PROJECT_ROOT / 'PhotoArts.xcodeproj' / 'project.pbxproj'
PROJECT_XCODEPROJ = PROJECT_ROOT / 'PhotoArts.xcodeproj'
xxx_SDK_PATH = PROJECT_ROOT / 'XXX'

# File types to process
SOURCE_FILE_EXTENSIONS = %w[.h .m .mm .swift .mpp .cpp .c].freeze
RESOURCE_FILE_EXTENSIONS = %w[.xib .storyboard .plist .json .strings .bundle .ttf .jpg .jpeg .pdf].freeze

# Ignored file types (no need to check)
IGNORED_FILE_EXTENSIONS = %w[.png .otf .bmp].freeze

# Ignored files and directories
IGNORE_PATTERNS = [
  '.git',
  '.svn',
  '.DS_Store',
  '*.xcuserstate',
  '*.xcworkspace',
  'build',
  'DerivedData',
  'Pods',
  '.bundle'
].freeze

# Ignored specific files (custom)
IGNORE_FILES = [
  'xxx/pcu/PopGrip/SelectTemplate/Controller/MDPopGripSelectTemplateViewController.m',
  'xxx/pcu/Dynamic/Resources/Sticker_add_photo.png',
  'xxx/pcu/Calendar/View/CustomEventSyncViewModel.swift',
  'xxx/pcu/Calendar/View/CustomEventSyncViewController.swift',
  'xxx/pcu/Calendar/View/CustomEventSyncView.swift',
  'xxx/pcu/Calendar/View/CustomEventSyncModel.swift',
  'xxx/pcu/Calendar/View/CustomEventImportBannerView.swift',
  'xxx/pcu/CustomMessage/SuggestForMe/Resources/MDMagicLoadingCenter-ca-fr.json',
  'xxx/pcu/McRib/View/MDCanvasFrameViewController.h',
  'xxx/pcu/McRib/View/MDCanvasFrameViewController.m',
  'xxx/pcu/PhotoArt/Design/ViewControllers/FPAAdjustPhotoViewController.swift',
  'xxx/pcu/PhotoArt/Design/Views/FPAAdjustPhotoContainerView.swift',
  'xxx/UCD/Template/Resources/Cards/94723345.json',
  'xxx/UCD/Template/Resources/B2C/84185669.json',
  'xxx/UCD/Template/Resources/B2bMug/495057.json',
  'xxx/UCD/Template/Resources/PDP/uucd_shop_detail.json',
  'xxx/UCD/Template/Manager/UCDTemplateHelper+GroupPhoto.swift',
  'xxx/UCD/Tracker/PRTUCDAmpTrackAdapter.swift',
  'xxx/basic/Helper/TutorialPage/MDTutorialPageBaseView.m',
  'xxx/basic/Helper/TutorialPage/MDTutorialPageManager.h',
  'xxx/basic/Helper/TutorialPage/MDTutorialPageBaseView.h',
  'xxx/basic/Helper/TutorialPage/MDTutorialPageManager.m',
  'xxx/photobook/Common/WorkFlow/Pages/OrderConfirm/WDConfirmViewController.m',
  'xxx/photobook/Common/WorkFlow/Pages/DesignYourPhotoBook/ContainerViewController/WDGiftCalendarContainerViewController+CustomEvents.m',
  'xxx/photobook/Common/WorkFlow/Pages/DesignYourPhotoBook/ContainerViewController/WDGiftCalendarContainerViewController+CustomEvents.h',
  'xxx/common/SweepStakesView/MDSweepStakesInviteView.swift'
].freeze

def should_ignore_file(file_path)
  path_str = file_path.to_s
  IGNORE_PATTERNS.any? { |pattern| path_str.include?(pattern) }
end

def scan_xxx_files
  xxx_files = []
  
  return xxx_files unless xxx_SDK_PATH.exist?
  
  xxx_SDK_PATH.find do |file_path|
    # Skip directories
    next unless file_path.file?
    
    # Skip files that should be ignored
    next if should_ignore_file(file_path)
    
    # Check file extension
    ext = file_path.extname.downcase
    
    # Skip explicitly ignored file types
    next if IGNORED_FILE_EXTENSIONS.include?(ext)
    
    next unless SOURCE_FILE_EXTENSIONS.include?(ext) || RESOURCE_FILE_EXTENSIONS.include?(ext)
    
    # Ignore .xcassets directories and files
    next if file_path.to_s.include?('.xcassets')
    
    # Check if in ignore list
    begin
      relative = file_path.relative_path_from(xxx_SDK_PATH)
      relative_str = relative.to_s.gsub('\\', '/')
      
      # Ignore xxx/assets and xxx/basic/Resources folders
      next if relative_str.start_with?('xxx/assets/') || relative_str.start_with?('xxx/basic/Resources/')
      
      # Check specific file ignore list
      next if IGNORE_FILES.include?(relative_str)
    rescue ArgumentError
      # If unable to calculate relative path, skip the file
      next
    end
    
    xxx_files << file_path
  end
  
  xxx_files
end

def find_or_create_group(project, path_components, parent_group)
  # Recursively find or create groups by hierarchy, ensuring each group's path points to the corresponding directory name
  return parent_group if path_components.nil? || path_components.empty?

  group_name = path_components.first
  existing = parent_group.children.find { |c| c.isa == 'PBXGroup' && c.display_name == group_name }
  group = existing || parent_group.new_group(group_name, group_name)

  find_or_create_group(project, path_components[1..-1], group)
end

def parse_pbxproj
  file_refs = {}
  existing_files = Set.new
  all_filenames = Set.new
  
  return [file_refs, existing_files, all_filenames] unless PROJECT_FILE.exist?
  
  content = File.read(PROJECT_FILE, encoding: 'utf-8')
  
  # Extract all file references (only extract those with complete paths)
  file_ref_pattern = /(\w{24})\s+\/\*\s+([^*]+)\s+\*\/\s*=\s*\{[^}]*isa\s*=\s*PBXFileReference[^}]*path\s*=\s*([^;]+);/
  content.scan(file_ref_pattern) do |match|
    uuid_key = match[0]
    filename = match[1].strip
    path = match[2].strip.gsub(/^"|"$/, '')
    
    # Only care about XXX related files
    if path.include?('XXX') || path.start_with?('xxx/')
      file_refs[path] = uuid_key
      existing_files.add(path)
    end
  end
  
  # Extract all filenames (for quick lookup)
  filename_pattern = %r{/\*\s+([^*/]+\.(h|m|mm|swift|xib|storyboard|plist|json|strings))\s+\*/}
  content.scan(filename_pattern) do |match|
    all_filenames.add(match[0].strip)
  end
  
  [file_refs, existing_files, all_filenames]
end

def get_xxx_relative_path(file_path)
  begin
    relative = file_path.relative_path_from(xxx_SDK_PATH)
    relative_str = relative.to_s.gsub('\\', '/')
    
    # Use unified XXX/ prefix format
    if relative_str.start_with?('xxx/')
      "XXX/#{relative_str}"
    else
      "XXX/#{relative_str}"
    end
  rescue ArgumentError
    file_path.to_s
  end
end

def add_files_to_xcodeproj(new_files)
  puts "\nAdding new files to Xcode project..."
  
  project = Xcodeproj::Project.open(PROJECT_XCODEPROJ.to_s)
  main_target = project.targets.find { |t| t.name == 'paus' }
  
  unless main_target
    puts "Error: Cannot find target named 'PhotoArts'"
    return false
  end
  
  # Get or create XXX group, and set its path to the disk directory to avoid generating incorrect relative paths
  main_group = project.main_group
  xxx_group = main_group['XXX'] || main_group.new_group('XXX', 'XXX')
  xxx_group.path ||= 'XXX'
  
  added_count = 0
  
  new_files.each do |file_path|
    # Calculate path relative to XXX
    begin
      relative_to_xxx = file_path.relative_path_from(xxx_SDK_PATH).to_s.gsub('\\', '/')
    rescue ArgumentError
      relative_to_xxx = file_path.to_s
    end

    # Existing check: using real_path to compare disk paths is most reliable
    existing_file = project.files.find { |f| f.real_path && f.real_path.to_s == file_path.to_s }
    if existing_file
      puts "  Skipped (already exists): XXX/#{relative_to_xxx}"
      next
    end

    # Determine file type
    ext = file_path.extname.downcase
    source_build_exts = %w[.m .mm .swift .cpp .c .mpp]
    is_source_file = source_build_exts.include?(ext)
    is_resource_file = RESOURCE_FILE_EXTENSIONS.include?(ext)

    # Create corresponding group structure
    path_parts = relative_to_xxx.split('/')
    file_name = path_parts.pop
    target_group = path_parts.empty? ? xxx_group : find_or_create_group(project, path_parts, xxx_group)

    # Create file reference under target group, using relative filename
    file_ref = target_group.new_file(file_name)

    # Add to target's build phases
    if main_target
      if is_source_file
        main_target.source_build_phase.add_file_reference(file_ref, true)
      elsif is_resource_file
        main_target.resources_build_phase.add_file_reference(file_ref, true)
      end
    end

    puts "  Added: XXX/#{relative_to_xxx}"
    added_count += 1
  end
  
  project.save
  puts "New files have been added to Xcode project. Please confirm and compile in Xcode."
  puts "Total #{added_count} files added"
  
  true
rescue => e
  puts "Error: Failed to add files to Xcode project: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  false
end

def main
  puts "Starting to scan XXX files..."
  
  # Scan files
  xxx_files = scan_xxx_files
  puts "Found #{xxx_files.length} files"
  
  # Parse project file
  puts "Parsing Xcode project file..."
  file_refs, existing_files, all_filenames = parse_pbxproj
  
  # Find new files (using set lookup, O(1) time complexity)
  puts "Checking filename matches..."
  new_files = []
  
  xxx_files.each do |file_path|
    relative_path = get_xxx_relative_path(file_path)
    filename = file_path.basename.to_s
    
    # Check if file already exists
    is_existing = false
    
    # 1. Check complete path match
    if file_refs.key?(relative_path)
      is_existing = true
    # 2. Check if same path exists in existing_files
    elsif existing_files.include?(relative_path)
      is_existing = true
    # 3. Quick check if filename exists in project file (using set lookup, O(1))
    elsif all_filenames.include?(filename)
      # If filename exists as PBXFileReference, consider the file is already in the project
      # Because the project compiles successfully, it means these file references are already configured
      is_existing = true
    # 4. Check if existing_files has same filename and path match
    else
      existing_files.each do |existing_path|
        if existing_path.end_with?(filename)
          # Further check if paths match (compare after normalization)
          existing_normalized = existing_path.gsub(/XXX\/?/, '').strip.gsub(/^\//, '')
          relative_normalized = relative_path.gsub(/XXX\/?/, '').strip.gsub(/^\//, '')
          if existing_normalized == relative_normalized
            is_existing = true
            break
          end
        end
      end
    end
    
    new_files << file_path unless is_existing
  end
  
  if new_files.empty?
    puts "\n✓ No new files found, all files are already in the project."
    return 0
  end
  
  puts "\nFound #{new_files.length} new files not added to project:"
  new_files.each do |file_path|
    puts "  - #{get_xxx_relative_path(file_path)}"
  end
  
  puts "\nSummary:"
  puts "  Total files scanned: #{xxx_files.length}"
  puts "  Already in project: #{xxx_files.length - new_files.length}"
  puts "  Need to add: #{new_files.length}"
  
  # Automatically add new files to Xcode project
  add_files_to_xcodeproj(new_files)
  
  0
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  1
end

exit(main) if __FILE__ == $PROGRAM_NAME

