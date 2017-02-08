require_relative 'logging'

module PoAndXliffConsolidator
  module Transform

    include Logging

    def match_with_ending(msgid, tu)

      msgid_chomped = Transform.intelligent_chomp(msgid)
      tu_msgid_chomped = Transform.intelligent_chomp(tu.msgid)

      msgid_chomped[:beginning] + matched_string(msgid_chomped[:str], tu_msgid_chomped[:str], tu.msgstr) + msgid_chomped[:ending]
    end

    def self.intelligent_chomp_string(str)
      Transform.intelligent_chomp(str)[:str]
    end

    def self.intelligent_chomp(str)
      beginning = ''
      ending = ''

      @leading_space_regex ||= /^[ \t]+/

      if match = @leading_space_regex.match(str)
        beginning += match[0]
        str = str.sub(@leading_space_regex, '')
      end

      @trailing_regexes ||= [
          /[ \t\n]+$/,
          /[!:…]+$/,
          /\.{2,5}$/,
      ]

      run_loop = true
      while run_loop do
        run_loop = false
        @trailing_regexes.each do |trailing_regex|
          if match = trailing_regex.match(str)
            ending = match[0] + ending
            str = str.sub(trailing_regex, '')
            run_loop = true
          end
        end
      end

      {
          str: str,
          beginning: beginning,
          ending: ending
      }


    end

    def chomped(string)
      string.chomp(':').chomp('!').chomp('...').chomp('..').chomp('…').strip
    end

    def matched_string(s1, s2, t)
      if s1 == s2
        t
      elsif s1 == s2.upcase
        t.upcase
      elsif s1 == s2.downcase
        t
      elsif s1 == s2.capitalize
        t.capitalize
      elsif s1 == s2.split.map(&:capitalize).join(' ')
        t.split.map(&:capitalize).join(' ')
      else
        logger.info "Couldn't 100% match #{s1} to #{s2}.. using #{t}"
        t
      end
    end
  end
end
