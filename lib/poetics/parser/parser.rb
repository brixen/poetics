class Poetics::Parser
# STANDALONE START
    def setup_parser(str, debug=false)
      @string = str
      @pos = 0
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @failed_rule = nil
      @failing_rule_offset = -1

      setup_foreign_grammar
    end

    # This is distinct from setup_parser so that a standalone parser
    # can redefine #initialize and still have access to the proper
    # parser setup code.
    #
    def initialize(str, debug=false)
      setup_parser(str, debug)
    end

    attr_reader :string
    attr_reader :failing_rule_offset
    attr_accessor :result, :pos

    # STANDALONE START
    def current_column(target=pos)
      if c = string.rindex("\n", target-1)
        return target - c - 1
      end

      target + 1
    end

    def current_line(target=pos)
      cur_offset = 0
      cur_line = 0

      string.each_line do |line|
        cur_line += 1
        cur_offset += line.size
        return cur_line if cur_offset >= target
      end

      -1
    end

    def lines
      lines = []
      string.each_line { |l| lines << l }
      lines
    end

    #

    def get_text(start)
      @string[start..@pos-1]
    end

    def show_pos
      width = 10
      if @pos < width
        "#{@pos} (\"#{@string[0,@pos]}\" @ \"#{@string[@pos,width]}\")"
      else
        "#{@pos} (\"... #{@string[@pos - width, width]}\" @ \"#{@string[@pos,width]}\")"
      end
    end

    def failure_info
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "line #{l}, column #{c}: failed rule '#{info.name}' = '#{info.rendered}'"
      else
        "line #{l}, column #{c}: failed rule '#{@failed_rule}'"
      end
    end

    def failure_caret
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      line = lines[l-1]
      "#{line}\n#{' ' * (c - 1)}^"
    end

    def failure_character
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset
      lines[l-1][c-1, 1]
    end

    def failure_oneline
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      char = lines[l-1][c-1, 1]

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "@#{l}:#{c} failed rule '#{info.name}', got '#{char}'"
      else
        "@#{l}:#{c} failed rule '#{@failed_rule}', got '#{char}'"
      end
    end

    class ParseError < RuntimeError
    end

    def raise_error
      raise ParseError, failure_oneline
    end

    def show_error(io=STDOUT)
      error_pos = @failing_rule_offset
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      io.puts "On line #{line_no}, column #{col_no}:"

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        io.puts "Failed to match '#{info.rendered}' (rule '#{info.name}')"
      else
        io.puts "Failed to match rule '#{@failed_rule}'"
      end

      io.puts "Got: #{string[error_pos,1].inspect}"
      line = lines[line_no-1]
      io.puts "=> #{line}"
      io.print(" " * (col_no + 3))
      io.puts "^"
    end

    def set_failed_rule(name)
      if @pos > @failing_rule_offset
        @failed_rule = name
        @failing_rule_offset = @pos
      end
    end

    attr_reader :failed_rule

    def match_string(str)
      len = str.size
      if @string[pos,len] == str
        @pos += len
        return str
      end

      return nil
    end

    def scan(reg)
      if m = reg.match(@string[@pos..-1])
        width = m.end(0)
        @pos += width
        return true
      end

      return nil
    end

    if "".respond_to? :getbyte
      def get_byte
        if @pos >= @string.size
          return nil
        end

        s = @string.getbyte @pos
        @pos += 1
        s
      end
    else
      def get_byte
        if @pos >= @string.size
          return nil
        end

        s = @string[@pos]
        @pos += 1
        s
      end
    end

    def parse(rule=nil)
      if !rule
        _root ? true : false
      else
        # This is not shared with code_generator.rb so this can be standalone
        method = rule.gsub("-","_hyphen_")
        __send__("_#{method}") ? true : false
      end
    end

    class LeftRecursive
      def initialize(detected=false)
        @detected = detected
      end

      attr_accessor :detected
    end

    class MemoEntry
      def initialize(ans, pos)
        @ans = ans
        @pos = pos
        @uses = 1
        @result = nil
      end

      attr_reader :ans, :pos, :uses, :result

      def inc!
        @uses += 1
      end

      def move!(ans, pos, result)
        @ans = ans
        @pos = pos
        @result = result
      end
    end

    def external_invoke(other, rule, *args)
      old_pos = @pos
      old_string = @string

      @pos = other.pos
      @string = other.string

      begin
        if val = __send__(rule, *args)
          other.pos = @pos
          other.result = @result
        else
          other.set_failed_rule "#{self.class}##{rule}"
        end
        val
      ensure
        @pos = old_pos
        @string = old_string
      end
    end

    def apply_with_args(rule, *args)
      memo_key = [rule, args]
      if m = @memoizations[memo_key][@pos]
        m.inc!

        prev = @pos
        @pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        lr = LeftRecursive.new(false)
        m = MemoEntry.new(lr, @pos)
        @memoizations[memo_key][@pos] = m
        start_pos = @pos

        ans = __send__ rule, *args

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr.detected
          return grow_lr(rule, args, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def apply(rule)
      if m = @memoizations[rule][@pos]
        m.inc!

        prev = @pos
        @pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        lr = LeftRecursive.new(false)
        m = MemoEntry.new(lr, @pos)
        @memoizations[rule][@pos] = m
        start_pos = @pos

        ans = __send__ rule

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr.detected
          return grow_lr(rule, nil, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def grow_lr(rule, args, start_pos, m)
      while true
        @pos = start_pos
        @result = m.result

        if args
          ans = __send__ rule, *args
        else
          ans = __send__ rule
        end
        return nil unless ans

        break if @pos <= m.pos

        m.move! ans, @pos, @result
      end

      @result = m.result
      @pos = m.pos
      return m.ans
    end

    class RuleInfo
      def initialize(name, rendered)
        @name = name
        @rendered = rendered
      end

      attr_reader :name, :rendered
    end

    def self.rule_info(name, rendered)
      RuleInfo.new(name, rendered)
    end

    #
  def setup_foreign_grammar; end

  # root = - value? - end
  def _root

    _save = self.pos
    while true # sequence
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_value)
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_end)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  # end = !.
  def _end
    _save = self.pos
    _tmp = get_byte
    _tmp = _tmp ? nil : true
    self.pos = _save
    set_failed_rule :_end unless _tmp
    return _tmp
  end

  # - = (" " | "\t" | "\n")*
  def __hyphen_
    while true

      _save1 = self.pos
      while true # choice
        _tmp = match_string(" ")
        break if _tmp
        self.pos = _save1
        _tmp = match_string("\t")
        break if _tmp
        self.pos = _save1
        _tmp = match_string("\n")
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      break unless _tmp
    end
    _tmp = true
    set_failed_rule :__hyphen_ unless _tmp
    return _tmp
  end

  # value = (string | number | boolean)
  def _value

    _save = self.pos
    while true # choice
      _tmp = apply(:_string)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_number)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_boolean)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_value unless _tmp
    return _tmp
  end

  # boolean = position (true | false | null | undefined)
  def _boolean

    _save = self.pos
    while true # sequence
      _tmp = apply(:_position)
      unless _tmp
        self.pos = _save
        break
      end

      _save1 = self.pos
      while true # choice
        _tmp = apply(:_true)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_false)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_null)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_undefined)
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_boolean unless _tmp
    return _tmp
  end

  # true = "true" {true_value}
  def _true

    _save = self.pos
    while true # sequence
      _tmp = match_string("true")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; true_value; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_true unless _tmp
    return _tmp
  end

  # false = "false" {false_value}
  def _false

    _save = self.pos
    while true # sequence
      _tmp = match_string("false")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; false_value; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_false unless _tmp
    return _tmp
  end

  # null = "null" {null_value}
  def _null

    _save = self.pos
    while true # sequence
      _tmp = match_string("null")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; null_value; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_null unless _tmp
    return _tmp
  end

  # undefined = "undefined" {undefined_value}
  def _undefined

    _save = self.pos
    while true # sequence
      _tmp = match_string("undefined")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; undefined_value; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_undefined unless _tmp
    return _tmp
  end

  # number = position (real | hex | int)
  def _number

    _save = self.pos
    while true # sequence
      _tmp = apply(:_position)
      unless _tmp
        self.pos = _save
        break
      end

      _save1 = self.pos
      while true # choice
        _tmp = apply(:_real)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_hex)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_int)
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_number unless _tmp
    return _tmp
  end

  # hexdigits = /[0-9A-Fa-f]/
  def _hexdigits
    _tmp = scan(/\A(?-mix:[0-9A-Fa-f])/)
    set_failed_rule :_hexdigits unless _tmp
    return _tmp
  end

  # hex = "0x" < hexdigits+ > {hexadecimal(text)}
  def _hex

    _save = self.pos
    while true # sequence
      _tmp = match_string("0x")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _save1 = self.pos
      _tmp = apply(:_hexdigits)
      if _tmp
        while true
          _tmp = apply(:_hexdigits)
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save1
      end
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; hexadecimal(text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_hex unless _tmp
    return _tmp
  end

  # digits = ("0" | /[1-9]/ /[0-9]/*)
  def _digits

    _save = self.pos
    while true # choice
      _tmp = match_string("0")
      break if _tmp
      self.pos = _save

      _save1 = self.pos
      while true # sequence
        _tmp = scan(/\A(?-mix:[1-9])/)
        unless _tmp
          self.pos = _save1
          break
        end
        while true
          _tmp = scan(/\A(?-mix:[0-9])/)
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_digits unless _tmp
    return _tmp
  end

  # int = < digits > {number(text)}
  def _int

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = apply(:_digits)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; number(text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_int unless _tmp
    return _tmp
  end

  # real = < digits "." digits ("e" /[-+]/? /[0-9]/+)? > {number(text)}
  def _real

    _save = self.pos
    while true # sequence
      _text_start = self.pos

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_digits)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string(".")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_digits)
        unless _tmp
          self.pos = _save1
          break
        end
        _save2 = self.pos

        _save3 = self.pos
        while true # sequence
          _tmp = match_string("e")
          unless _tmp
            self.pos = _save3
            break
          end
          _save4 = self.pos
          _tmp = scan(/\A(?-mix:[-+])/)
          unless _tmp
            _tmp = true
            self.pos = _save4
          end
          unless _tmp
            self.pos = _save3
            break
          end
          _save5 = self.pos
          _tmp = scan(/\A(?-mix:[0-9])/)
          if _tmp
            while true
              _tmp = scan(/\A(?-mix:[0-9])/)
              break unless _tmp
            end
            _tmp = true
          else
            self.pos = _save5
          end
          unless _tmp
            self.pos = _save3
          end
          break
        end # end sequence

        unless _tmp
          _tmp = true
          self.pos = _save2
        end
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; number(text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_real unless _tmp
    return _tmp
  end

  # string = position "\"" < /[^\\"]*/ > "\"" {string_value(text)}
  def _string

    _save = self.pos
    while true # sequence
      _tmp = apply(:_position)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("\"")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[^\\"]*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("\"")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; string_value(text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_string unless _tmp
    return _tmp
  end

  # line = { current_line }
  def _line
    @result = begin;  current_line ; end
    _tmp = true
    set_failed_rule :_line unless _tmp
    return _tmp
  end

  # column = { current_column }
  def _column
    @result = begin;  current_column ; end
    _tmp = true
    set_failed_rule :_column unless _tmp
    return _tmp
  end

  # position = line:l column:c { position(l, c) }
  def _position

    _save = self.pos
    while true # sequence
      _tmp = apply(:_line)
      l = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_column)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  position(l, c) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_position unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "- value? - end")
  Rules[:_end] = rule_info("end", "!.")
  Rules[:__hyphen_] = rule_info("-", "(\" \" | \"\\t\" | \"\\n\")*")
  Rules[:_value] = rule_info("value", "(string | number | boolean)")
  Rules[:_boolean] = rule_info("boolean", "position (true | false | null | undefined)")
  Rules[:_true] = rule_info("true", "\"true\" {true_value}")
  Rules[:_false] = rule_info("false", "\"false\" {false_value}")
  Rules[:_null] = rule_info("null", "\"null\" {null_value}")
  Rules[:_undefined] = rule_info("undefined", "\"undefined\" {undefined_value}")
  Rules[:_number] = rule_info("number", "position (real | hex | int)")
  Rules[:_hexdigits] = rule_info("hexdigits", "/[0-9A-Fa-f]/")
  Rules[:_hex] = rule_info("hex", "\"0x\" < hexdigits+ > {hexadecimal(text)}")
  Rules[:_digits] = rule_info("digits", "(\"0\" | /[1-9]/ /[0-9]/*)")
  Rules[:_int] = rule_info("int", "< digits > {number(text)}")
  Rules[:_real] = rule_info("real", "< digits \".\" digits (\"e\" /[-+]/? /[0-9]/+)? > {number(text)}")
  Rules[:_string] = rule_info("string", "position \"\\\"\" < /[^\\\\\"]*/ > \"\\\"\" {string_value(text)}")
  Rules[:_line] = rule_info("line", "{ current_line }")
  Rules[:_column] = rule_info("column", "{ current_column }")
  Rules[:_position] = rule_info("position", "line:l column:c { position(l, c) }")
end
