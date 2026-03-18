#!/usr/bin/env ruby
# Ensures iOS Podfile contains a post_install patch that strips unsupported '-G' compiler flags
# (seen with BoringSSL-GRPC / gRPC-Core toolchain mismatches during Xcode archive in CI).
#
# This script is idempotent: it adds the patch only if not already present.

PODFILE_PATH = File.expand_path("Podfile", __dir__)

unless File.exist?(PODFILE_PATH)
  warn "Podfile not found at #{PODFILE_PATH}"
  exit 1
end

contents = File.read(PODFILE_PATH)

marker_begin = "# BEGIN CI -G STRIP PATCH"
marker_end   = "# END CI -G STRIP PATCH"

if contents.include?(marker_begin) && contents.include?(marker_end)
  puts "Podfile already patched (markers found)."
  exit 0
end

patch = <<~RUBY

  #{marker_begin}
  # Strip unsupported '-G' / '-G*' tokens from pod build flags and xcconfig files.
  # This is a CI safety net for Xcode clang error:
  #   unsupported option '-G' for target 'arm64-apple-ios...'
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings['GCC_GENERATE_DEBUGGING_SYMBOLS'] = 'NO'
        config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'

        %w[OTHER_CFLAGS OTHER_CPLUSPLUSFLAGS OTHER_SWIFT_FLAGS OTHER_LDFLAGS].each do |flag_key|
          flags = config.build_settings[flag_key]
          if flags.is_a?(Array)
            config.build_settings[flag_key] = flags.reject { |f| t = f.to_s.strip; t == '-G' || t.start_with?('-G') }
          elsif flags.is_a?(String)
            config.build_settings[flag_key] = flags.split(/\\s+/).reject { |t| t == '-G' || t.start_with?('-G') }.join(' ').strip
          end
        end
      end
    end

    xcconfig_globs = [
      "Pods/Target Support Files/BoringSSL-GRPC/**/*.xcconfig",
      "Pods/Target Support Files/gRPC-Core/**/*.xcconfig",
      "Pods/Target Support Files/FirebaseMessaging/**/*.xcconfig",
      "Pods/Target Support Files/FirebaseCore/**/*.xcconfig",
    ]

    xcconfig_globs.each do |glob|
      Dir.glob(glob).each do |path|
        begin
          txt = File.read(path)
          next unless txt.include?("-G")
          updated = txt.lines.map do |line|
            if line =~ /OTHER_(CFLAGS|CPLUSPLUSFLAGS|LDFLAGS|SWIFT_FLAGS)\\s*=/
              tokens = line.split(/\\s+/)
              tokens.reject! { |t| t == '-G' || t.start_with?('-G') }
              tokens.join(' ')
            else
              line
            end
          end.join
          File.write(path, updated) if updated != txt
        rescue => e
          Pod::UI.warn("Could not patch xcconfig \#{path}: \#{e}")
        end
      end
    end
  end
  #{marker_end}
RUBY

File.open(PODFILE_PATH, "a") { |f| f.write(patch) }
puts "Patched Podfile (appended CI -G strip patch)."

