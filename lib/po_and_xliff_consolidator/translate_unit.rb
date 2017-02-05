require_relative 'logging'

module PoAndXliffConsolidator
  class TranslateUnit
    include Comparable
    include Logging

    attr_accessor :msgid
    attr :msgstr
    attr :msgid_downcase
    attr :msgid_downcase_singular
    attr :priority

    @@priorities = []

    def <=>(a_n_other)
      return -1 if priority < a_n_other.priority
      return 1 if priority > a_n_other.priority
      return -1 if msgid_downcase_singular < a_n_other.msgid_downcase_singular
      return 1 if msgid_downcase_singular > a_n_other.msgid_downcase_singular
      msgid_downcase <=> a_n_other.msgid_downcase
    end

    def chomp_all(str)
      str.strip.chomp.chomp(':').chomp('...').chomp('..').chomp('…')
    end

    def initialize(msgid, msgstr)
      @msgid = chomp_all(msgid)
      @msgstr = chomp_all(msgstr)
      @msgid_downcase = TranslateUnit::msgid_key(msgid)
      @msgid_downcase_singular = @msgid_downcase.chomp('s')

      @@priorities.each_with_index do |string, index|
        if msgid_downcase.include? string
          @priority = index
          break
        end
        @priority = @@priorities.count
      end
    end

    def self.msgid_key(msgid)
      Transform::intelligent_chomp(msgid)[:str].downcase
    end

    def ==(other)
      self.class === other and msgid_downcase == other.msgid_downcase
    end

    alias eql? ==

    def hash
      msgid_downcase.hash
    end

    def inspect
      @msgid
    end

    def to_s
      msgid
    end
  end
end
