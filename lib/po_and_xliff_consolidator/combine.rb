require_relative 'translate_unit'
require_relative 'manipulate'
require_relative 'file_handle'
require_relative 'logging'

require 'nokogiri'
require 'words_counted'
require 'csv'

module PoAndXliffConsolidator
  class Combine

    include Manipulate
    include FileHandle
    include Logging

    attr_accessor :make_xliffs_blank

    def process(language_code)
      set_language_codes(language_code)
      reset_stores
      process_dictionary_file
      process_web_app
      process_xliff
      write_output_file
      write_csv_file
      logger.info "#{@translation_units.count} translation units"
      logger.info "#{@untranslated_count} untranslated phrases"
      logger.info "#{@untranslated_word_count} untranslated words"
      logger.info "#{@duplicate_count} duplicates"
    end

    def write_output_file
      fp = File.open(combined_file_name,'w')
      comments_need_adding = true
      @headers.each do |header|
        if comments_need_adding && header =~ /^msgid\s""$/
          fp.puts "# #{@translation_units.count} translation units (phrases)"
          fp.puts "# #{@untranslated_count} untranslated phrases"
          fp.puts "# #{@untranslated_word_count} untranslated words"
          fp.puts "# #{@duplicate_count} duplicates"
          fp.puts '#'
          comments_need_adding = false
        end
        fp.puts header
      end

      @translation_units.sort!
      @translation_units.each do |tu|
        fp.puts "msgid \"#{tu.msgid}\""
        fp.puts "msgstr \"#{tu.msgstr}\""
        fp.puts
      end

      @unsolved_blocks.each do |ub|
        ub.each do |ube|
          fp.puts ube
        end
        fp.puts
      end

      fp.close
    end

    def write_csv_file
      @translation_units.sort!
      CSV.open(csv_file_name, "wb") do |csv|
        @translation_units.each do |tu|
          csv << [tu.msgid, tu.msgstr]
        end
      end
    end

    def process_dictionary_file
      fp = File.open(dictionary_file_name, 'r')

      while (line = fp.gets)
        break if line.strip == ''
      end

      while (line = fp.gets)
        if match1 = @msgid_regex.match(line)
          msgid = match1[1]
          if line = fp.gets
            while match1c = @continuation_regex.match(line)
              msgid += match1c[1]
              line = fp.gets
            end
            if match2 = @msgstr_regex.match(line)
              msgstr = match2[1]
              if line = fp.gets
                while match2c = @continuation_regex.match(line)
                  msgstr += match2c[1]
                  line = fp.gets
                end
              end
              add_translation_unit(msgid, msgstr)
            elsif match2 = @msgid_plural_regex.match(line)
              block = [match1[0], match2[0]]
              line = fp.gets
              while line && line.strip != ''
                block << line
                line = fp.gets
              end
              @unsolved_blocks << block
            else
              throw "I don't know what to do.."
            end
          end

        end
      end
      fp.close
    end

    def process_web_app
      fp = web_app_file_pointer(:need_translating,'r')

      while(line = fp.gets)
        @headers << line
        break if line.strip == ''
      end

      while(line = fp.gets)
        if match1 = @msgid_regex.match(line)
          msgid = match1[1]
          if line = fp.gets
            if match2 = @msgstr_regex.match(line)
              msgstr = match2[1]
              add_translation_unit(msgid, msgstr)
            elsif match2 = @msgid_plural_regex.match(line)
              block = [match1[0], match2[0]]
              line = fp.gets
              while line.strip != ''
                block << line
                line = fp.gets
              end
              @unsolved_blocks << block
            else
              puts line
              throw "I don't know what to do.."
            end
          end

        end
      end
      fp.close
    end



    def process_xliff
      xcode_doc(:need_translating).xpath('//xmlns:file').each do |xcode_file_node|
        xcode_file_node.xpath('xmlns:body/xmlns:trans-unit').each do |xcode_trans_unit_node|
          xcode_source = xcode_trans_unit_node.xpath('xmlns:source').last
          xcode_targets = xcode_trans_unit_node.xpath('xmlns:target')
          msgid = xcode_source.text
          msgstr = ''
          xtc = xcode_targets.count
          if xtc == 1
            msgstr = xcode_targets.first.text
          elsif xtc > 1
            throw "I don't know what to do.."
          end
          if make_xliffs_blank
            msgstr = ''
          end
          add_translation_unit(msgid, msgstr)
        end
      end
    end

  end
end
