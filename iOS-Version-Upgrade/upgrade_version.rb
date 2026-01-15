#!/usr/bin/env ruby
# frozen_string_literal: true

# iOS project version upgrade ruby shell
# 用法: ruby upgrade_version.rb <new_version>
# 例如: ruby upgrade_version.rb MAJOR.MINOR.PATCH

require 'fileutils'

# 项目根目录 (scripts 目录的父目录)
PROJECT_ROOT = File.expand_path('..', __dir__)

# 定义需要更新版本号的文件列表
VERSION_FILES = [
  # 主应用 Info.plist 文件
  'xxus/xxus-Info.plist',
  'xxuk/xxuk-Info.plist',
  'xxnl/xxnl-Info.plist',
  'xxit/xxit-Info.plist',
  'xxie/xxie-Info.plist',
  'xxfr/xxfr-Info.plist',
  'xxes/xxes-Info.plist',
  'xxde/xxde-Info.plist',
  'xxca/xxca-Info.plist',

  # Settings.bundle Root.plist 文件
  'xxus/Settings.bundle/Root.plist',
  'xxuk/Settings.bundle/Root.plist',
  'xxnl/Settings.bundle/Root.plist',
  'xxit/Settings.bundle/Root.plist',
  'xxie/Settings.bundle/Root.plist',
  'xxfr/Settings.bundle/Root.plist',
  'xxes/Settings.bundle/Root.plist',
  'xxde/Settings.bundle/Root.plist',
  'xxca/Settings.bundle/Root.plist',

  # Notification Service Extension Info.plist 文件
  'notificationServiceExt_us/Info.plist',
  'notificationServiceExt_uk/Info.plist',
  'notificationServiceExt_nl/Info.plist',
  'notificationServiceExt_it/Info.plist',
  'notificationServiceExt_ie/Info.plist',
  'notificationServiceExt_fr/Info.plist',
  'notificationServiceExt_es/Info.plist',
  'notificationServiceExt_de/Info.plist'
].freeze

# 版本号格式验证 (支持 x.y.z 格式)
VERSION_REGEX = /^\d+\.\d+\.\d+$/

# 用于匹配 plist 中版本号的正则表达式
# 匹配 <key>CFBundleShortVersionString</key> 后面的 <string>x.y.z</string>
PLIST_VERSION_REGEX = /(<key>CFBundleShortVersionString<\/key>\s*<string>)\d+\.\d+\.\d+(<\/string>)/

# 匹配 Settings.bundle 中 DefaultValue 的版本号
SETTINGS_VERSION_REGEX = /(<key>DefaultValue<\/key>\s*<string>)\d+\.\d+\.\d+(<\/string>)/

def colorize(text, color_code)
  "\e[#{color_code}m#{text}\e[0m"
end

def green(text)
  colorize(text, 32)
end

def red(text)
  colorize(text, 31)
end

def yellow(text)
  colorize(text, 33)
end

def cyan(text)
  colorize(text, 36)
end

def get_current_version
  # 从 xxus/xxus-Info.plist 获取当前版本号
  info_plist = File.join(PROJECT_ROOT, 'xxus/xxus-Info.plist')
  return nil unless File.exist?(info_plist)

  content = File.read(info_plist)
  match = content.match(/<key>CFBundleShortVersionString<\/key>\s*<string>(\d+\.\d+\.\d+)<\/string>/)
  match ? match[1] : nil
end

def update_version_in_file(file_path, new_version)
  full_path = File.join(PROJECT_ROOT, file_path)

  unless File.exist?(full_path)
    puts "  #{red('✗')} 文件不存在: #{file_path}"
    return false
  end

  content = File.read(full_path)
  original_content = content.dup

  # 根据文件类型选择不同的替换策略
  if file_path.include?('Settings.bundle')
    content.gsub!(SETTINGS_VERSION_REGEX, "\\1#{new_version}\\2")
  else
    content.gsub!(PLIST_VERSION_REGEX, "\\1#{new_version}\\2")
  end

  if content == original_content
    puts "  #{yellow('○')} 未修改 (版本号可能已是目标版本): #{file_path}"
    return false
  end

  File.write(full_path, content)
  puts "  #{green('✓')} 已更新: #{file_path}"
  true
end

def print_usage
  puts <<~USAGE

    #{cyan('XXX iOS 版本号批量更新工具')}
    #{'=' * 40}

    #{yellow('用法:')}
      ruby upgrade_version.rb <new_version>

    #{yellow('参数:')}
      new_version  新版本号 (格式: x.y.z)

    #{yellow('示例:')}
      ruby upgrade_version.rb 4.34.0
      ruby upgrade_version.rb 5.0.0

    #{yellow('当前版本:')} #{get_current_version || '未知'}

  USAGE
end

def main
  if ARGV.empty? || ARGV[0] == '-h' || ARGV[0] == '--help'
    print_usage
    exit(0)
  end

  new_version = ARGV[0]

  unless new_version.match?(VERSION_REGEX)
    puts red("\n错误: 版本号格式不正确!")
    puts "版本号必须是 x.y.z 格式 (例如: 4.34.0)"
    exit(1)
  end

  current_version = get_current_version

  puts "\n#{cyan('XXX iOS 版本号更新')}"
  puts '=' * 40
  puts "当前版本: #{yellow(current_version || '未知')}"
  puts "目标版本: #{green(new_version)}"
  puts '=' * 40

  if current_version == new_version
    puts yellow("\n版本号相同，无需更新。")
    exit(0)
  end

  puts "\n开始更新版本号...\n"

  updated_count = 0
  failed_count = 0

  VERSION_FILES.each do |file|
    if update_version_in_file(file, new_version)
      updated_count += 1
    else
      failed_count += 1
    end
  end

  puts "\n#{'=' * 40}"
  puts "更新完成!"
  puts "  #{green('成功')}: #{updated_count} 个文件"
  puts "  #{yellow('未修改/失败')}: #{failed_count} 个文件" if failed_count.positive?
  puts "\n#{cyan("版本已从 #{current_version} 更新到 #{new_version}")}" if updated_count.positive?
end

main
