require 'nokogiri'
require 'words_counted'

require_relative 'translate_unit'
require_relative 'manipulate'
require_relative 'transform'
require_relative 'file_handle'
require_relative 'logging'

module PoAndXliffConsolidator
  class Extract

    include Manipulate
    include FileHandle
    include Transform
    include Logging

    def process(language_code)
      logger.info "Processing #{language_code}"
      set_language_codes(language_code)
      reset_stores
      process_combined_file
      update_po_file
      # write_csv_file
      update_xliff_file
      # create_xamarin_file
    end

    def process_combined_file
      fp = File.open(combined_file_name, 'r')

      while (line = fp.gets)
        @headers << line
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
            #if msgid.include? 'Congratulations'
            #  puts 'hi'
            #end
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

    def xamarin_base_doc
      @xamarin_base_doc ||= get_xamarin_base_doc
    end

    def update_po_file
      fp = web_app_file_pointer(:need_translating, 'r')
      fp2 = web_app_file_pointer(:translated, 'w')

      while (line = fp.gets)
        fp2.puts line
        break if line.strip == ''
      end

      while (line = fp.gets)
        if match1 = @msgid_regex.match(line)
          msgid = match1[1]
          msgid_line = line
          if line = fp.gets
            while match1c = @continuation_regex.match(line)
              msgid += match1c[1]
              line = fp.gets
            end
            if match2 = @msgstr_regex.match(line)
              old_msgstr = match2[1]
              msgstr = get_msgstr(msgid)
              if old_msgstr.strip != msgstr.strip
                if old_msgstr == "" || old_msgstr == msgid
                  if msgid != msgstr
                    logger.info "Adding `#{msgid}` as `#{msgstr}`"
                  end
                else
                  logger.info "Revising `#{msgid}` from `#{old_msgstr}` to `#{msgstr}`"
                end
              end
              fp2.puts msgid_line
              fp2.puts "msgstr \"#{msgstr}\""
              fp2.puts
            elsif @msgid_plural_regex.match(line)
              line = fp.gets
              while line.strip != ''
                line = fp.gets
              end
            else
              throw "I don't know what to do.."
            end
          end
        end
      end

      @unsolved_blocks.each do |ub|
        ub.each do |ube|
          fp2.puts ube
        end
        fp2.puts
      end


      fp.close
      fp2.close

    end


    def create_xamarin_file
      xamarin_doc = get_xamarin_base_doc

      xamarin_doc.xpath('//data').each do |xamarin_data_node|
        value_node = xamarin_data_node.xpath('value').first
        msgid = value_node.text
        begin
          msgstr = get_msgstr(msgid)
        rescue
          logger.warn "Couldn't find Xamarin text `#{msgid}` - using `#{msgid}`"
          msgstr = msgid
        end
        value_node.content = msgstr
      end

      doc_string = xamarin_doc.to_s
      File.write(xamarin_file_name(:translated), doc_string)

    end

    def update_xliff_file
      changes = 0

      xcode_doc = xcode_doc(:need_translating)

      xcode_doc.xpath('//xmlns:file').each do |xcode_file_node|
        xcode_file_node.xpath('xmlns:body/xmlns:trans-unit').each do |xcode_trans_unit_node|
          xcode_source_nodes = xcode_trans_unit_node.xpath('xmlns:source')
          if xcode_source_nodes.count != 1
            throw "I don't know what to do!"
          end
          msgid = xcode_source_nodes.first.text
          msgstr = get_msgstr(msgid)

          xcode_targets = xcode_trans_unit_node.xpath('xmlns:target')
          xtc = xcode_targets.count
          if xtc == 0
            if msgstr != ''
              new_node = Nokogiri::XML::Node.new('target', xcode_doc)
              new_node.content = msgstr
              xcode_source_nodes.last.add_next_sibling new_node
              changes += 1
              if msgid != msgstr
                logger.info "Adding `#{msgid}` as `#{msgstr}`"
              end
            else
              logger.info "Not creating #{msgid} because content is blank"
            end

          elsif xtc == 1
            old_msgstr = xcode_targets.text
            if old_msgstr.strip != msgstr.strip
              logger.info "Revising `#{msgid}` from `#{old_msgstr}` to `#{msgstr}`"
              xcode_targets.last.content = msgstr
              changes += 1
            elsif old_msgstr != msgstr
              logger.info "Revising spacing for `#{msgid}` from `#{old_msgstr}` to `#{msgstr}`"
              xcode_targets.last.content = msgstr
              changes += 1
            else
              logger.debug "No change for `#{msgid}`"
            end
          else
            throw "I don't know what to do if there are two target nodes"
          end
        end
      end

      if changes > 0
        logger.debug 'Saving xliff..'
        doc_string = xcode_doc.to_s.gsub('</source><target>', "</source>\n        <target>")
        File.write(xcode_file_name(:translated), doc_string)
      else
        logger.debug 'No changes - not saving!'
      end

    end

    def tweak_regexes
      # Because in (for example) Chinese and Japanese character sets, if we try to match_with_ending,
      # we can end up with double character blocks like:
      #
      # ！!
      # 。.
      #
      # So we just tweak these here...


      @tweak_regexes ||= {
          utf8_and_ascii_colon: [/\uFF1A:/,"\uFF1A".encode('utf-8')],
          utf8_and_ascii_dotdotdot1: [/\u3002\.\.\./,"\u3002".encode('utf-8')],
          utf8_and_ascii_dotdotdot2: [/\u3002…/,"\u3002".encode('utf-8')],
          utf8_and_ascii_fullstop: [/\u3002\./,"\u3002".encode('utf-8')],
          utf8_and_ascii_exclamation: [/\uFF01!/,"\uFF01".encode('utf-8')],
          utf8_full_stop_and_ascii_exclamation: [/\u3002!/,"\u3002".encode('utf-8')]
      }
    end

    def character_set_tweaks(str)
      tweak_regexes.each do |intent, regex_arr|
        str.gsub!(regex_arr[0],regex_arr[1])
      end
      str
    end

    def get_msgstr(msgid)
      return msgid if should_skip?(msgid)

      key = TranslateUnit::msgid_key(msgid)
      tu = @translation_units.find { |tu| tu.msgid_downcase == key }

      if tu
        if tu.msgstr == ""
          logger.warn "#{@language_code}: No translation for #{msgid} - msgstr is empty"
          return ''
        end

        if msgid.include? '%'
          check_string_format_specifiers(msgid, tu.msgstr)
        end

        if msgid == tu.msgid
          return tu.msgstr
        else
          return character_set_tweaks(match_with_ending(msgid, tu))
        end
      else
        if msgid.include? '{0}'
          tu = @translation_units.find { |tu| tu.msgid_xamarin == key }
          if tu
            msgstr = TranslateUnit::xamarin_equivalent(tu.msgstr)
            return msgstr
          end
        end

        if msgid == 'Y'
          return 'Y'
        end

        if msgid == 'N'
          return 'N'
        end

        logger.warn "Cannot find `#{msgid}` - looking for `#{key}`"
        return ""
      end

    end

    def extract_regexes
      @extract_regexes ||= {
          fastgettext_regex: /%\{[a-zA-Z0-9_]+\}/,
          xyz_regex: /%[a-zA-Z0-9_]+%/,
          xcode_regex: /(%)([\d]+[$]+)*(h|hh|l|ll|q|L|z|t|j)*(\$)*(.02)*(@|d|D|u|U|x|X|o|O|f|e|E|g|G|c|C|s|S|p|a|A|F)/,
          n_percent_regex: /\d+%/
      }
    end

    def check_string_format_specifiers(msgid, msgstr)
      if msgid.include? '%'
        logs = []
        logs << 'Checking for matching string format specifiers... '
        logs << msgid
        logs << msgstr

        msgid_temp = msgid.dup
        msgstr_temp = msgstr.dup

        extract_regexes.each do |intent, regex|
          results = msgid_temp.scan(regex)
          results.each do |result|
            result = result.join('') if result.is_a? Array
            if msgstr_temp.index result
              logs << "Matched #{result}"
              msgid_temp.sub!(result, '')
              msgstr_temp.sub!(result, '')
            else
              logs.each do |log|
                logger.debug log
              end
              throw "Cannot find #{result} for #{@language_code}"
            end
          end
        end

        if msgid_temp.include? '%'
          throw "Missed something in #{msgid}"
        end

        if msgstr_temp.include? '%'
          throw "Something extra in #{msgstr}"
        end
      end
    end


  end
end
