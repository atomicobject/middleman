require "sass"
require "compass"

module Middleman
  module Sass  
    def self.included(base)
      base.supported_formats << "sass"
    end

    def render_path(path)
      if template_exists?(path, :sass)
        begin
          static_version = options.public + request.path_info
          send_file(static_version) if File.exists? static_version

          location_of_sass_file = options.environment == "build" ? options.build_dir : options.public
          css_filename = File.join(Dir.pwd, location_of_sass_file) + request.path_info
          sass(path.to_sym, ::Compass.sass_engine_options.merge({ :css_filename => css_filename }))
        rescue Exception => e
          sass_exception_string(e)
        end
      else
        super
      end
    end

    # Handle Sass errors
    def sass_exception_string(e)
      e_string = "#{e.class}: #{e.message}"

      if e.is_a? ::Sass::SyntaxError
        e_string << "\non line #{e.sass_line}"

        if e.sass_filename
          e_string << " of #{e.sass_filename}"

          if File.exists?(e.sass_filename)
            e_string << "\n\n"

            min = [e.sass_line - 5, 0].max
            begin
              File.read(e.sass_filename).rstrip.split("\n")[
                min .. e.sass_line + 5
              ].each_with_index do |line, i|
                e_string << "#{min + i + 1}: #{line}\n"
              end
            rescue
              e_string << "Couldn't read sass file: #{e.sass_filename}"
            end
          end
        end
      end
      <<END
/*
#{e_string}

Backtrace:\n#{e.backtrace.join("\n")}
*/
body:before {
white-space: pre;
font-family: monospace;
content: "#{e_string.gsub('"', '\"').gsub("\n", '\\A ')}"; }
END
    end
  end
end

class Middleman::Base
  include Middleman::Sass
  
  after do 
    ::Compass.configuration do |config|
      config.project_path     = self.root
      config.sass_dir         = File.join(File.basename(self.views), self.css_dir)
      config.output_style     = :nested
      config.css_dir          = File.join(File.basename(self.public), self.css_dir)
      config.images_dir       = File.join(File.basename(self.public), self.images_dir)

      config.add_import_path(config.sass_dir)
      
      config.http_images_path      = self.http_images_path rescue File.join(self.http_prefix, self.images_dir)
      config.http_stylesheets_path = self.http_css_path rescue File.join(self.http_prefix, self.css_dir)
    
      if self.cache_buster?
        config.asset_cache_buster do |path, real_path|
          if File.readable?(real_path)
            File.mtime(real_path).strftime("%s") 
          else
            $stderr.puts "WARNING: '#{File.basename(path)}' was not found (or cannot be read) in #{File.dirname(real_path)}"
          end
        end
      else
        config.asset_cache_buster do
          false
        end
      end
    end

    configure :build do
      ::Compass.configuration do |config|
        config.css_dir          = File.join(File.basename(self.build_dir), self.css_dir)
        config.images_dir       = File.join(File.basename(self.build_dir), self.images_dir)
      end
    end
    
    ::Compass.configure_sass_plugin!
  end
end