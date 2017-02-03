require_relative 'logging'

module PoAndXliffConsolidator
  module FileHandle
    include Logging

    attr_accessor :path_templates
    attr_accessor :root_file_path
    attr_accessor :app_name

    def initialize
      @path_templates = {
          need_translating: {
              po: ['%{root_file_path}','web-app','need-translating','locales','%{language_code}','%{app_name}.po'],
              xliff: ['%{root_file_path}','xliff','need-translating','%{xliff_language_code}.xliff']
          },
          translated: {
              po: ['%{root_file_path}','web-app','translated','locales','%{language_code}','%{app_name}.po'],
              xliff: ['%{root_file_path}','xliff','translated','%{xliff_language_code}.xliff'],
          },
          combined: ['%{root_file_path}','combined','%{language_code}.po']
      }
      super
    end

    def get_path(path_array)
      File.join(path_array.map{|p| p.gsub('%{root_file_path}',@root_file_path).gsub('%{language_code}',@language_code).gsub('%{xliff_language_code}',@xliff_language_code).gsub('%{app_name}',@app_name)})
    end

    def combined_file_name
      get_path(path_templates[:combined])
    end

    def web_app_filename(subfolder)
      get_path(path_templates[subfolder][:po])
    end

    def xcode_file_name(subfolder)
      get_path(path_templates[subfolder][:xliff])
    end

    def web_app_file_pointer(subfolder, mode)
      fn = web_app_filename(subfolder)
      logger.debug "Opening #{fn}"
      File.open(fn, mode)
    end

    def xcode_doc(subfolder)
      fn = xcode_file_name(subfolder)
      logger.debug "Opening #{fn}"
      Nokogiri.XML(File.open(fn))
    end
  end
end
