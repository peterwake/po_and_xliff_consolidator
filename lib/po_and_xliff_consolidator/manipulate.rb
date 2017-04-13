require_relative 'logging'

module PoAndXliffConsolidator
  module Manipulate

    include Logging

    attr_accessor :skip_strings
    attr_accessor :skip_regexes
    attr_accessor :reset_identical_msgid_and_msgstr
    attr_accessor :translation_units

    def initialize
      reset_stores

      @skip_strings = []
      @skip_regexes = []

      @reset_identical_msgid_and_msgstr = false

      @msgid_regex = /^msgid\s"(.*)"$/
      @msgid_plural_regex = /^msgid_plural\s"(.*)"$/
      @msgstr_regex = /^msgstr\s"(.*)"$/
      @continuation_regex = /^"(.*)"$/

      super
    end

    def set_language_codes(language_code)
      if language_code.is_a? Array
        @language_code = language_code[0]
        @xliff_language_code = language_code[1]
      else
        @language_code = language_code
        @xliff_language_code = language_code
      end
    end

    def reset_stores
      @translation_units = []
      @headers = []
      @unsolved_blocks = []
      @duplicate_count = 0
      @untranslated_count = 0
      @untranslated_word_count = 0
    end

    def should_skip?(msgid)
      if skip_strings.include? msgid
        return true
      end

      skip_regexes.each do |skip_regex|
        if skip_regex =~ msgid
          return true
        end
      end

      false
    end

    def add_translation_unit(msgid, msgstr)

      return if should_skip?(msgid)

      if msgid == msgstr
        logger.warn "#{@language_code}: identical msgid and msgstr for: #{msgid}"
        if @reset_identical_msgid_and_msgstr
          msgstr = ''
        end
      end

      tu = TranslateUnit.new(msgid, msgstr)

      if @translation_units.include? tu
        tu2 = @translation_units.find {|tux| tux == tu}

        if Analyse::quality(tu.msgid) > Analyse::quality(tu2.msgid)
          logger.debug "Decided msgid `#{tu}` is better quality than `#{tu2}`"
          tu2.msgid = tu.msgid
          if tu.msgstr != ''
            logger.debug "Replacing `#{tu2.msgstr}` with `#{tu.msgstr}`"
            tu2.msgstr = tu.msgstr
          end
        end

        if tu2.msgstr == ''
          logger.debug "Setting #{tu2} to use #{tu.msgstr}"
          tu2.msgstr = tu.msgstr
        else
          logger.debug "Already found #{tu}"
          @duplicate_count += 1
        end

        return
      end

      @translation_units << tu
      if msgstr == ''
        @untranslated_count += 1
        counter = WordsCounted.count(msgid)
        word_count = counter.token_count
        @untranslated_word_count += word_count
      end

    end
  end
end
