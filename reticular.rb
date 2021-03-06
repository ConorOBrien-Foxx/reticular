require_relative "funcs"

class Func
    def initialize(body, parent_instance)
        @body = body
        @parent = parent_instance
    end
    
    attr_accessor :body
    attr_accessor :parent
    
    def exec(*args)
        # TODO
        # Dear past me,
        #   What on earth did I have to do??? please be more responsible
        # in the future. Thanks,
        # --a concerned but also past me
        child = Reticular.new(@body + ";", args)
        @parent.adopt(child)
        child.execute
        child.adopt(@parent)
    end
    
    # execute without bidirectional adoption
    def temp_exec(*args)
        child = Reticular.new(@body + ";", args)
        child.execute
        child.stack
    end
    
    # alias for execute
    def [](*args)
        self.exec(*args)
    end

    # also an alias for execute
    def call(*args)
        self.exec(*args)
    end
    
    def to_s
        return "[#{@body}]"
    end
    
    def inspect
        self.to_s
    end
end

# an n-ary function for use in defining operators
def nary(n, sym, f_map, preserve = false)
    lambda { |instance|
        top = instance.stack.pop n
        (instance.stack.concat top) if preserve
        types = top.map { |item| item.class }
        func = nil
        f_map.each do |dest_type, f|
            i = -1
            valid = dest_type.all? { |d_t|
                i += 1
                d_t == :any || (
                    d_t == :num && [Fixnum, Float, Bignum].any? { |c|
                        types[i] == c
                    }
                ) || d_t == types[i] }
            if valid
                func = f
                break
            end
        end
        
        if func == nil
            instance.print_state
            raise "operator `#{sym}` does not have behaviour for types [#{types.join(", ")}] at #{instance.pointer.to_s}."
        end
        args = top
        args += [instance] if func.arity > n
        instance.stack.push func.call(*args)
    }
end

def nary_preserve(n, sym, f_map)
    nary(n, sym, f_map, true)
end

def binary(*args)
    nary(2, *args)
end

def unary(*args)
    nary(1, *args)
end

def unary_preserve(*args)
    nary_preserve(1, *args)
end

def nilary(f)
    lambda { |instance| instance.push f[] }
end

class Reticular
    @@commands = {
        " "  => lambda { |instance|
            instance.skip_whitespace
            instance.rewind
        },
        ">"  => lambda { |instance| instance.dir.update( 1,  0) },
        "<"  => lambda { |instance| instance.dir.update(-1,  0) },
        "v"  => lambda { |instance| instance.dir.update( 0,  1) },
        "^"  => lambda { |instance| instance.dir.update( 0, -1) },
        "/"  => lambda { |instance|
            instance.dir.x, instance.dir.y = -instance.dir.y, -instance.dir.x
        },
        "\\" => lambda { |instance|
            instance.dir.x, instance.dir.y = instance.dir.y, instance.dir.x
        },
        "!"  => lambda { |instance| instance.advance },
        ";"  => lambda { |instance| instance.stop },
        ":"  => lambda { |instance|
            instance.advance
            instance.stack.push instance.current
        },
        "+"  => binary("+", {
            [Func, Func] => lambda { |f, g| Func.new(f.body + g.body, f.parent) },
            [Array, Array] => lambda { |x, y| [].concat(x).concat y },
            [Array, :any] => lambda { |x, y| x.map {|e| e + y} },
            [:any, Array] => lambda { |x, y| y.map {|e| x + e} },
            [String, String] => lambda { |x, y| x + y },
            [:num, :num] => lambda { |x, y| x + y },
        }),
        "*"  => binary("*", {
            [Array, Array] => lambda { |x, y| x.product y },
            [String, String] => lambda { |x, y|
                x.chars.product(y.chars).map { |x| x.join } .join
            },
            [String, Array] => lambda { |x, y|
                x.chars.product(y).map { |x| x.join } .join
            },
            [Array, String] => lambda { |x, y|
                x.product(y.chars).map { |x| x.join } .join
            },
            [Func, Fixnum] => lambda { |f, n|
                n.times { f.exec }
                f.parent.stack.pop  # remove return result
            },
            [Fixnum, String] => lambda { |n, s|
                s * n
            },
            [Array, :any] => lambda { |x, y| x.map {|e| e * y} },
            [:any, Array] => lambda { |x, y| y.map {|e| x * e} },
            [:any, :any] => lambda { |x, y| x * y },
        }),
        "-"  => binary("-", {
            # set difference, a1 \ a2
            [Array, Array] => lambda { |a1, a2|
                a1.select { |e| !a2.include? e }
            },
            [String, String] => lambda { |str, rpl|
                del = Regexp.new Regexp.escape rpl
                str.gsub del, ""
            },
            [:any, :any] => lambda { |x, y| x - y },
        }),
        "%"  => binary("%", {
            [Fixnum, Fixnum]   => lambda { |x, y| sround x.to_f / y.to_f },
            [Fixnum, Float]    => lambda { |x, y| x.to_f / y },
            [Float, Fixnum]    => lambda { |x, y| x / y.to_f },
            [Float, Float]     => lambda { |x, y| x / y },
            [:num, :num]       => lambda { |x, y| x / y},
        }),
        ","  => binary(",", {
            # array union
            [Array, Array]     => lambda { |a1, a2|
                a1.select { |e| a2.include? e }
            },
            [:num, :num]       => lambda { |x, y| x % y},
        }),
        "&"  => binary("&", {
            [Array, :any]  => lambda { |a, v| a.push v },
            [:any, :any]   => lambda { |x, y| (x.to_f / y.to_f).to_i }
        }),
        "$"  => lambda { |instance| instance.stack.pop },
        "~"  => lambda { |instance| instance.get(2).reverse.each {|e| instance.stack.push e} },
        "="  => lambda { |instance|
            # ref, value = instance.get(2)
            value, ref = instance.get(2)
            instance.variables[ref] = value
        },
        "_"  => lambda { |instance|
            instance.dir.update(-1 + 2 * (falsey?(instance.stack.pop) ? 1 : 0), 0)
        },
        "|"  => lambda { |instance|
            instance.dir.update(0, -1 + 2 * (falsey?(instance.stack.pop) ? 1 : 0))
        },
        "`"  => lambda { |instance|
            instance.push instance.variables[instance.stack.pop]
        },
        "?"  => lambda { |instance|
            instance.advance if falsey? instance.stack.top
        },
        "@?" => nary(3, "@?", {
            [Func, Func, :any] => lambda { |f, g, n|
                falsey? n ? f : g
            }
        }),
        "."  => lambda { |instance|
            instance.advance
            cmd = instance.current
            instance.stack.push instance.variables[cmd]
        },
        # extended functions
        "#"  => lambda { |instance|
            entry = instance.stack.pop
            unless instance.ext_cmds.has_key? entry
                raise "error: `#` has no extension `#{entry}` at " + instance.pointer.inspect
            end
            instance.ext_cmds[entry].call(instance)
        },
        "@`" => lambda { |instance| instance.print_state },
        "@@" => lambda { |instance|
            # up if 1, right if 0, down if -1
            val = instance.stack.pop
            s_val = val <=> 0
            # todo: fix "else" case
            instance.dir.update(*case s_val
                when -1
                    [0, 1]
                when 0
                    [1, 0]
                else # when 1
                    [0, -1]
            end)
        },
        "a"  => lambda { |instance|
            top = instance.stack.pop
            arg = instance.args[top]
            unless defined? arg
                instance.print_state
                raise "in `a`: argument #{top} does not exist."
            end
            instance.push arg
        },
        "A"  => lambda { |instance| instance.push instance.args },
        "b"  => lambda { |instance|
            top = instance.stack.pop
            if top.class != Fixnum
                raise "in `b`: expected argument #{top} to be Fixnum, got type #{top.class}."
            end
            instance.push instance.stack.pop top},
        "B"  => lambda { |instance|
            instance.stack += instance.stack.pop
        },
        "c"  => unary("c", {
            [Array]  => lambda { |x| x.pop },
            [Fixnum] => lambda { |x| x.chr },
            [String] => lambda { |x| x.codepoints[0] },
        }),
        "C"  => binary("C", {
            [:any, :any] => lambda { |x, y| x <=> y },
        }),
        "@c" => binary("@c", {
            [:any, :any] => lambda { |x, y| x.count y},
        }),
        "@C" => lambda { |instance| clear },
        "d"  => lambda { |instance| instance.push instance.stack.top },
        "D"  => lambda { |instance| instance.stack.size.times { |i|
            instance.push instance.stack[i]
        } },
        "@d" => lambda { |instance| 
            n = instance.stack.pop
            s = instance.stack.size
            n.times { |i|
                instance.push instance.stack[s - n + i]
            }
        },
        "e"  => nilary(constant Math::E),
        "E"  => binary("E", {
            [:any, :any] => lambda { |x, y| x == y ? 1 : 0 },
        }),
        "f"  => unary("n", {
            [Array] => lambda { },
            [:any] => lambda { |x| x.to_f },
        }),
        "F"  => lambda { |instance|
            # H
            hash, key = instance.get(2)
            instance.push hash
            begin
                instance.push hash[key]
            rescue
                instance.push hash.send(key)
            end
            # g
            instance.stack.pop.exec
        },
        "g"  => lambda { |instance|
            instance.stack.pop.exec
        },
        "@g" => lambda { |instance|
            instance.stack.push instance.gen
        },
        "G"  => lambda { |instance|
            args = instance.get(instance.stack.pop)
            instance.stack.pop.exec args
        },
        "h"  => lambda { |instance|
            hash, key, value = instance.get(3)
            hash[key] = value
            instance.push hash
        },
        "@H" => binary("@H", {
            [Fixnum, Fixnum] => lambda { |a, b|
                str_a = a.to_s
                str_a[b % str_a.size].to_i
            },
            [:any, Fixnum] => lambda { |a, b|
                a[b % a.size]
            }
        }),
        "@h" => binary("@h", {
            [Fixnum, Fixnum] => lambda { |a, b|
                a.to_s[b].to_i
            },
            [:any, Fixnum] => lambda { |a, b|
                a[b]
            }
        }),
        "H"  => lambda { |instance|
            hash, key = instance.get(2)
            instance.push hash
            begin
                instance.push hash[key]
            rescue
                instance.push hash.send(key)
            end
        },
        "i"  => lambda { |instance| instance.push $stdin.gets.chomp },
        "I"  => lambda { |instance| instance.push all_input },
        "@i" => nilary(lambda { get_char }),
        "@I" => nary(3, "@I", {
            [Array, :any, Func] => lambda { |arr, start, fun|
                arr.inject(start) { |p, c| fun.temp_exec(p, c).pop }
            },
        }),
        "j"  => lambda { |instance| instance.stack.pop.to_i.times { instance.advance } },
        "J"  => binary("J", {
            [:any, :any] => lambda { |x, y| x ** y },
        }),
        "k"  => lambda { |instance|
            instance.advance
            redef = instance.read_command
            instance.commands[redef] = instance.stack.pop
        },
        # K is used
        "l"  => lambda { |instance| instance.push instance.stack.size },
        "L"  => unary_preserve("L", {
            [Fixnum] => lambda { |x| Math.log10(x).to_i },
            [Float]  => lambda { |x| Math.log10(x).to_i },
            [:any]   => lambda { |x| x.size },
        }),
        "m"  => lambda { |instance| instance.stack.push instance.stack.shift },
        "M"  => lambda { |instance| instance.stack.unshift instance.stack.pop },
        "n"  => unary("n", {
            [:any] => lambda { |x| sround x }
        }),
        "N"  => nilary(constant nil),
        "o"  => lambda { |instance| 
            entity = instance.stack.pop
            instance.output += entity.to_s
            print entity
        },
        "O"  => lambda { |instance| instance.stack.size.times {
            entity = instance.stack.shift
            instance.output += entity.to_s
            print entity
        } },
        "p"  => lambda { |instance|
            entity = instance.stack.pop
            instance.output += entity.to_s
            puts entity
        },
        "P"  => lambda { |instance| instance.stack.size.times {
            entity = instance.stack.shift
            instance.output += entity.to_s
            puts entity
        } },
        "@p" => unary("@p", {
            [Fixnum] => lambda { |x| bool_to_i F.is_prime? x }
        }),
        "@P" => unary("@P", {
            [Fixnum] => lambda { |x| F.nth_prime x }
        }),
        "q"  => lambda { |instance| instance.stack.reverse! },
        "@q" => unary("@q", {
            [String] => lambda { |s| s.reverse },
            [Array]  => lambda { |s| s.reverse },
        }),
        "Q"  => unary("Q", {
            [:any] => lambda { |x| 1 - bool_to_i(x) }
        }),
        "@Q" => lambda { |instance|
            n = instance.stack.pop
            instance.stack.concat instance.stack.pop(n).reverse
        },
        "r"  => nilary(lambda { rand }),
        "R"  => binary("R", {[:any, :any] => lambda { |x, y| Array x .. y}}),
        "@r" => unary("@r", {[:any] => lambda { |x| x[rand 0 ... x.size] }}),
        "@R" => binary("@R", {[:any, :any] => lambda { |x, y| rand x .. y }}),
        "s"  => unary("s", {
            [:any] => lambda { |x| x.to_s },
        }),
        "S"  => unary("S", {
            [String] => lambda { |x| x.chars },
        }),
        "@s" => nary(3, "@s", {
            [String, String, Func] => lambda { |a, b, f|
                a.gsub(Regexp.new b) { |*a|
                    f.temp_exec(*a).pop
                }
            },
            [String, String, String] => lambda { |a, b, c|
                a.gsub(
                    Regexp.new(b),
                    c
                )
            },
            [:any, Fixnum, Fixnum] => lambda { |iter, a, b, instance|
                instance.stack.push iter[b + 1 .. -1]
                iter[a..b]
            },
        }),
        "@S" => lambda { |instance|
            iter, a, b = instance.stack.pop 3
            instance.stack.push iter
            instance.stack.push iter[a..b]
        },
        "t"  => lambda { |instance|
            x, y = instance.stack.pop 2
            instance.stack.push instance.field[y][x]
        },
        "T"  => unary("T", {
            [:any] => lambda { |x| x.class.name },
        }),
        "u"  => lambda { |instance|
            instance.advance
            cmd = instance.read_command
            ref = instance.stack.pop
            instance.stack.push instance.variables[ref]
            instance.commands[cmd].call(instance)
            result = instance.stack.pop
            instance.variables[ref] = result
        },
        "U"  => lambda { |instance|
            instance.dir.update(*instance.stack.pop(2))
        },
        "@U"  => lambda { |instance|
            (-instance.dir).each { |e| instance.push e }
        },
        #v used
        "V"  => unary("V", {
            [Array] => lambda { |x| x.last },
            [String] => lambda { |x| x[x.size - 1] },
        }),
        "@v" => lambda { |instance|
            x, y, s = instance.stack.pop 3
            instance.place s, x, y, false
            instance.pointer.x = -1
        },
        "@V" => lambda { |instance|
            s = instance.stack.pop
            instance.place s, 0, instance.pointer.y, false
            instance.pointer.x = -1
        },
        "w"  => lambda { |instance|
            sleep instance.stack.pop
        },
        "x"  => lambda { |instance|
            x, y, s = instance.stack.pop 3
            instance.place s, x, y, false
        },
        "@X" => lambda { |instance|
            x, y, s = instance.stack.pop 3
            instance.place s, x, y, true
        },
        "@x" => lambda { |instance|
            instance.stack.push instance.pointer.x
        },
        # X for random direction
        "y"  => binary("y", {
            [:any, :any] => lambda { |x, y| bool_to_i x < y }
        }),
        "@y" => lambda { |instance|
            instance.stack.push instance.pointer.y
        },
        "Y"  => binary("Y", {
            [:any, :any] => lambda { |x, y| bool_to_i x <= y }
        }),
        "z"  => binary("z", {
            [:any, :any] => lambda { |x, y| bool_to_i x > y }
        }),
        "Z"  => binary("Z", {
            [:any, :any] => lambda { |x, y| bool_to_i x >= y }
        }),
    }
    
    # used by `#`
    @@ext_cmds = {
        0   => unary("0#", {[:any] => lambda { |x| -x }}),
        1   => unary("1#", {[:any] => lambda { |x| Math.sin x }}),
        2   => unary("2#", {[:any] => lambda { |x| Math.cos x }}),
        3   => unary("3#", {[:any] => lambda { |x| Math.tan x }}),
        4   => unary("4#", {[:any] => lambda { |x| Math.asin x }}),
        5   => unary("5#", {[:any] => lambda { |x| Math.acos x }}),
        6   => unary("6#", {[:any] => lambda { |x| Math.atan x }}),
        7   => unary("7#", {[:any] => lambda { |x| Math.asinh x }}),
        8   => unary("8#", {[:any] => lambda { |x| Math.acosh x }}),
        9   => unary("9#", {[:any] => lambda { |x| Math.atanh x }}),
        "a" => binary("a#", {[:any, :any] => lambda { |y, x| Math.atan2 y, x}}),
        "b" => unary("b#", {[:any] => lambda { |x| Math.cbrt x }}),
        "c" => unary("c#", {[:any] => lambda { |x| Math.erf x }}),
        "d" => unary("d#", {[:any] => lambda { |x| Math.erfc x }}),
        "e" => unary("e#", {[:any] => lambda { |x| Math.exp x }}),
        "f" => unary("f#", {[:any] => lambda { |x| Math.frexp x }}),
        "g" => unary("g#", {[:any] => lambda { |x| Math.gamma x }}),
        "h" => binary("h#", {[:any, :any] => lambda { |x, y| Math.hypot x, y }}),
        "i" => binary("i#", {[:any, :any] => lambda { |x, y| Math.ldexp x, y }}),
        "j" => unary("j#", {[:any] => lambda { |x| Math.lgamma x }}),
        "k" => binary("k#", {[:any, :any] => lambda { |x, y| Math.log x, y }}),
        "l" => unary("l#", {[:any] => lambda { |x| Math.log x }}),
        "m" => unary("m#", {[:any] => lambda { |x| Math.log10 x }}),
        "n" => unary("n#", {[:any] => lambda { |x| Math.log2 x }}),
        "o" => unary("o#", {[:any] => lambda { |x| Math.sqrt x }}),
        "p" => nilary(constant Math::PI),
        "q" => binary("q#", {[:any, :any] => lambda { |x, y| [x, y].max }}),
        "r" => binary("r#", {[:any, :any] => lambda { |x, y| [x, y].min }}),
        "s" => unary("s#", {[:any] => lambda { |x| x.max }}),
        "t" => unary("t#", {[:any] => lambda { |x| x.min }}),
        Math::E => nilary(constant Infinity),
    }
    
    def initialize(code, args)
        @gen       = 0
        @dir       = Coordinate.new(1, 0)
        @args      = args
        @stack     = Stack.new
        @output    = ""
        @running   = false
        @pointer   = Coordinate.new(0, 0)
        @commands  = @@commands
        @ext_cmds  = @@ext_cmds
        @variables = {}
        
        if code.empty?
            @field = [[]]
            @width = @height = 0
            return self
        end
        
        @code      = code.gsub(/\t/, "    ").delete "\r"
        @width     = @code.lines.map { |line| line.chomp.size } .max || 0
        @height    = @code.lines.size
        @field     = @code.lines.map { |line| line.chomp.ljust(@width).chars }
        self
    end
    
    attr_accessor :gen
    attr_accessor :dir
    attr_accessor :args
    attr_accessor :code
    attr_accessor :field
    attr_accessor :stack
    attr_accessor :width
    attr_accessor :height
    attr_accessor :output
    attr_accessor :pointer
    attr_accessor :commands
    attr_accessor :ext_cmds
    attr_accessor :variables
    
    def boundary
        @code   = field.map(&:join).join "\n"
        @width  = @code.lines.map { |line| line.chomp.size } .max || 0
        @height = @code.lines.size
        @field  = @code.lines.map { |line| line.chomp.ljust(@width).chars }
    end
    
    def place(str, x, y, mask)
        str.lines.each.with_index { |line, i|
            line.chomp!
            @field[y + i] ||= []
            char_mask = line.chars
            if mask
                # TODO: mask does not work
                char_mask = char_mask.map.with_index { |chr, i|
                    chr == " " ? line.chars[i] : chr
                }
            end
            @field[y + i][x .. x + line.size] = char_mask
        }
        self.boundary
    end
    
    # gives relevant properties to the other instance
    def adopt(other)
        other.stack = @stack
        other.output = @output
        other.variables = @variables
    end
    
    def advance
        @pointer.move_bound(@dir, @width, @height)
    end
    
    def rewind
        @pointer.move_bound(Coordinate.new(-@dir.x, -@dir.y), @width, @height)
    end
    
    def current
        @pointer.from(@field)
    end
    
    def stop
        @running = false
    end
    
    def push(*a)
        @stack.push *a
    end
    
    def get(*a)
        @stack.pop *a
    end
    
    def expect(command)
        unless self.current == command
            raise "error, expected `#{command}`, received `#{self.current}` at #{@pointer.to_s}."
        end
        true
    end
    
    # moves to the next non-whitespace character
    def skip_whitespace
        self.advance while self.current == " "
    end
    
    def read_command
        build = ""
        cmd = self.current
        if cmd == "@" || cmd == "K"
            self.advance
            cmd += self.current
        end
        cmd
    end
    
    def read_str
        build = ""
        loop do
            self.advance
            break if @pointer.from(@field) == '"'
            
            if self.current == "\\"
                self.advance
                build += eval ("\\" + self.current).quote
            else
                build += self.current
            end
        end
        build
    end
    
    def read_raw_str
        build = ""
        loop do
            self.advance
            break if @pointer.from(@field) == '"'
            
            if self.current == "\\"
                self.advance
                if self.current == '"'
                    build += "'"
                else
                    build += "\\" + self.current
                end
            else
                build += self.current
            end
        end
        build
    end
    
    def read_func
        self.expect "["
        depth = 1
        build = ""
        # TODO: fix problem with strings in thing
        while depth != 0
            # puts build
            self.advance
            if self.current == "["
                depth += 1 
            elsif self.current == "]"
                depth -= 1
            # elsif self.current == '"'
                # self.advance
                # while self.current != '"'
                    # puts self.current
                    # self.advance if self.current == "\\"
                    # self.advance
                # end
            end
            build += self.current unless depth == 0
        end
        Func.new(build, self)
    end
    
    def read_object
        build_hash = {}
        self.advance    # move past the initial signal
        loop do
            name = self.read_str
            self.advance
            self.expect ":"
            self.advance
            build_hash[name] = self.read_func
            
            self.expect "]"
            self.advance
            
            break unless self.current == ","
            self.advance
        end
        build_hash
    end
    
    def execute(opts = {})
        # define defaults for opts
        opts["debug"] ||= false
        opts["debug_time"] ||= 0
        opts["max_gen"] ||= Infinity
        
        if @field == [[]]
            while true
                self.print_state(opts["debug_time"]) if opts["debug"]
            end
        end
        
        @running = true
        while @running
            if @gen >= opts["max_gen"]
                self.print_state
                raise "maximum generation size met"
            end
            
            self.print_state(opts["debug_time"]) if opts["debug"]
            
            cmd = self.read_command
            if @commands.has_key? cmd
                @commands[cmd].call(self)
            elsif cmd == '"'
                @stack.push self.read_str
            elsif cmd == '@"'
                @stack.push self.read_raw_str
            elsif cmd == "'"
                build = ""
                loop do
                    self.advance
                    break if @pointer.from(@field) == "'"
                    
                    build += self.current
                end
                @stack.push sround build
            elsif cmd == "["    # begin function definition
                @stack.push self.read_func
            elsif cmd == "{"
                @stack.push self.read_object
            elsif cmd =~ /[0-9]/
                @stack.push cmd.to_i
            else
                self.print_state
                raise "character `#{cmd}` is not a vaild instruction at (#{@pointer.to_s}."
            end
            
            self.advance
            @gen += 1
        end
        @running = false
    end
    
    def print_state(time = 0.5)
        clear
        i = 0
        x_pivot = @width - @pointer.x
        puts "\u250C" + "\u2500" * pointer.x + "\u252C" + "\u2500" * (x_pivot - 1) + "\u2510" 
        @field.each { |line|
            j = 0
            print @pointer.y == i ? "\u251C" : "\u2502"
            line.each { |char|
                if @pointer.same(j, i)
                    print highlight char
                else
                    print char
                end
                j += 1
            }
            puts @pointer.y == i ? "\u2524" : "\u2502"
            i += 1
        }
        puts "\u2514" + "\u2500" * pointer.x + "\u2534" + "\u2500" * (x_pivot - 1) + "\u2518\n\u250C STACK"
        puts "\u2502 " + pretty(@stack)
        puts "\u251C GENERATIONS: #{@gen}"
        puts "\u251C OUTPUT"
        puts output.gsub(/^/, "\u2502 ")
        puts "\u251C VARIABLES"
        @variables.each { |k, v|
            puts "\u251C\u2500 #{k} => #{pretty v}"
        }
        puts "\u2514"
        sleep time
    end
end

# execute program if run from this file
if __FILE__ == $0
    flags = []

    flag_arity = {
        "d" => 1,
        "debug" => 1,
        "t" => 1,
        "timeout" => 1,
        "r" => 0,
        "read" => 0,
        "p" => 0,
        "print_state" => 0,
    }

    other_args = []

    i = 0
    while i < ARGV.size
        argument = ARGV[i]
        unless nil == (argument =~ /^[-\/]/)
            flag = argument[1 .. -1]
            raise "undefined flag `#{flag}`" unless flag_arity.has_key? flag
            flags.push [flag, ARGV[i + 1 .. i + flag_arity[flag]]]
            i += flag_arity[flag]
        else
            other_args.push argument
        end
        i += 1
    end

    # initialize flag options
    opts = {
        "debug"       => false,
        "debug_time"  => nil,
        "max_gen"     => Infinity,
        "read_stdin"  => false,
        "print_state" => false,
    }

    # activate options
    flags.each { |arg|
        flag, options = arg
        if flag == "d" || flag == "debug"
            opts["debug"] = true
            opts["debug_time"] = options[0].to_f
        elsif flag == "t" || flag == "timeout"
            opts["max_gen"] = options[0].to_i
        elsif flag == "r" || flag == "read"
            opts["read_stdin"] = true
        elsif flag == "p" || flag == "print_state"
            opts["print_state"] = true
        end
    }

    if opts["read_stdin"]
        program = all_input
    elsif not other_args.first
        puts "no file given"
        exit
    else
        program = File.read(other_args.shift)
    end

    instance = Reticular.new(program, other_args)

    instance.execute opts

    instance.print_state if opts["print_state"]
end