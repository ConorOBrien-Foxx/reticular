load "funcs.rb"

class Coordinate
    def initialize(x, y)
        @x = x
        @y = y
    end
    
    def move(coor)
        if coor.is_a? Coordinate
            @x += coor.x
            @y += coor.y
        else
            raise TypeError, "coor is not a Coordinate instance"
        end
        self
    end
    
    def update(nx, ny)
        @x = nx
        @y = ny
        self
    end
    
    def from(item)
        begin
            item[@y][@x]
        rescue
            :no_char
        end
    end
    
    def same(nx, ny)
        nx == @x && ny == @y
    end
    
    def move_bound(dir, mx, my)
        self.move(dir)
        
        @x %= mx
        @y %= my
        self
    end
    
    attr_accessor :x
    attr_accessor :y
end

class Stack
    def initialize(arr = [])
        @data = arr
    end
    
    attr_accessor :data
    
    def top
        @data[-1]
    end
    
    def top=(v)
        @data.pop
        @data.push v
    end
    
    def push(v)
        @data.push v
    end
    
    def pop
        @data.pop
    end
    
    def get(n)
        res = []
        while n > 0
            res.push @data.pop
            n -= 1
        end
        res.reverse
    end
    
    def to_s
        pretty(@data)
    end
end

class Func
    def initialize(body, parent_instance)
        # puts body
        @body = body
        @parent = parent_instance
    end
    
    def exec(*args)
        # TODO
        child = Reticular.new(@body + ";", args)
        @parent.adopt(child)
        child.execute
        child.adopt(@parent)
    end
    
    def [](*args)
        self.exec(*args)
    end
    
    def to_s
        return "[#{@body}]"
    end
end

def nary(n, sym, f_map, preserve = false)
    lambda { |instance|
        top = instance.stack.get(n)
        (instance.stack.data.concat top) if preserve
        types = top.map { |item| item.class }
        func = nil
        f_map.each do |dest_type, f|
            i = -1
            valid = dest_type.all? { |d_t|
                i += 1
                d_t == :any || d_t == types[i] }
            if valid
                func = f
                break
            end
        end
        
        if func == nil
            raise "operator #{sym} does not have behaviour for types [#{types.join(", ")}]"
        end
        instance.stack.push func.call(*top)
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
        " "  => lambda { |instance| instance},
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
            [Array, Array] => lambda { |x, y| x.concat y },
            [Array, :any] => lambda { |x, y| x.map {|e| e + y} },
            [:any, Array] => lambda { |x, y| y.map {|e| x + e} },
            [:any, :any] => lambda { |x, y| x + y },
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
            [Array, :any] => lambda { |x, y| x.map {|e| e * y} },
            [:any, Array] => lambda { |x, y| y.map {|e| x * e} },
            [:any, :any] => lambda { |x, y| x * y },
        }),
        "-"  => binary("-", {
            [:any, :any] => lambda { |x, y| x - y },
        }),
        "%"  => binary("%", {
            [Fixnum, Fixnum]   => lambda { |x, y| x.to_f / y.to_f },
            [Fixnum, Float]    => lambda { |x, y| x.to_f / y },
            [Float, Fixnum]    => lambda { |x, y| x / y.to_f },
            [Float, Float]     => lambda { |x, y| x / y },
        }),
        "&"  => binary("&", {
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
            instance.dir.update(-1 + 2 * (falsey?(instance.stack.top) ? 1 : 0), 0)
        },
        "|"  => lambda { |instance|
            instance.dir.update(0, -1 + 2 * (falsey?(instance.stack.top) ? 1 : 0))
        },
        "`"  => lambda { |instance|
            instance.push instance.variables[instance.stack.pop]
        },
        "?"  => lambda { |instance|
            instance.advance if falsey? instance.stack.top
        },
        "@@" => lambda { |instance|
            # up if 1, right if 0, down if -1
            val = instance.stack.pop
            s_val = val <=> 0
            instance.dir.update(*case s_val
                when 1
                    [0, -1]
                when 0
                    [1, 0]
                when -1
                    [0, 1]
            end)
        },
        "a"  => lambda { |instance|
            top = instance.stack.pop
            arg = instance.args[top]
            unless defined? arg
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
            instance.push instance.stack.get top},
        "B"  => lambda { |instance|
            instance.stack.data += instance.stack.pop
        },
        "c"  => unary("c", {
            [Fixnum] => lambda { |x| x.chr },
            [String] => lambda { |x| x.codepoints[0] },
        }),
        "C"  => binary("C", {
            [:any, :any] => lambda { |x, y| x <=> y },
        }),
        "d"  => lambda { |instance| instance.push instance.stack.top },
        "D"  => lambda { |instance| instance.stack.data.size.times { |i|
            instance.push instance.stack.data[i]
        } },
        "e"  => nilary(Math.exp 1),
        "E"  => binary("E", {
            [:any, :any] => lambda { |x, y| x == y },
        }),
        "f"  => unary("n", {
            [:any] => lambda { |x| x.to_f }
        }),
        "F"  => lambda { |instance|
            hash, key = instance.get(2)
            instance.push hash
            instance.push hash[key]
        },
        "g"  => lambda { |instance|
            instance.stack.pop.exec
        },
        "H"  => lambda { |instance| instance.push Hash.new },
        "h"  => lambda { |instance|
            hash, key, value = instance.get(3)
            hash[key] = value
            instance.push hash
        },
        "i"  => lambda { |instance| instance.push $stdin.gets.chomp },
        "I"  => lambda { |instance| instance.push mutli_line_input },
        "l"  => lambda { |instance| instance.push instance.data.size },
        "L"  => unary_preserve("L", {
            [Fixnum] => lambda { |x| Math.log10(x).to_i },
            [:any]   => lambda { |x| x.size },
        }),
        "n"  => unary("n", {
            [:any] => lambda { |x| sround x }
        }),
        "N"  => nilary(constant nil),
        "o"  => lambda { |instance| 
            entity = instance.stack.pop
            instance.output += entity.to_s
            print entity
        },
        "O"  => lambda { |instance| instance.stack.data.size.times {
            entity = instance.stack.data.shift
            instance.output += entity.to_s
            print entity
        } },
        "p"  => lambda { |instance|
            entity = instance.stack.pop
            instance.output += entity.to_s
            puts entity
        },
        "P"  => lambda { |instance| instance.stack.data.size.times {
            entity = instance.stack.data.shift
            instance.output += entity.to_s
            puts entity
        } },
        "@p" => unary("@p", {
            [:any] => lambda { |x| F.is_prime? x }
        }),
        "@P" => unary("@P", {
            [:any] => lambda { |x| F.nth_prime x }
        }),
        "r"  => nilary(lambda { rand }),
        "R"  => binary("R", {[:any, :any] => lambda { |x, y| Array x .. y}}),
        "@R" => binary("@R", {[:any, :any] => lambda { |x, y| rand x .. y }}),
        "@r" => unary("@r", {[:any] => lambda { |x| x[rand 0 ... x.size] }}),
        "s"  => unary("s", {
            [:any] => lambda { |x| x.to_s },
        }),
        "S"  => unary("S", {
            [String] => lambda { |x| x.chars },
        }),
    }   
    
    def initialize(code, args)
        @dir       = Coordinate.new(1, 0)
        @args      = args
        @stack     = Stack.new
        @output    = ""
        @running   = false
        @pointer   = Coordinate.new(0, 0)
        @commands  = @@commands
        @variables = {}
        
        if code.empty?
            @field = [[]]
            @width = @height = 0
            return self
        end
        
        _code      = code.gsub(/\t/, "    ").delete "\r"
        @width     = _code.lines.map { |line| line.chomp.size } .max || 0
        @height    = _code.lines.size
        @field     = _code.lines.map { |line| line.chomp.ljust(@width).chars }
        self
    end
    
    attr_accessor :dir
    attr_accessor :args
    attr_accessor :field
    attr_accessor :stack
    attr_accessor :width
    attr_accessor :height
    attr_accessor :output
    attr_accessor :pointer
    attr_accessor :commands
    attr_accessor :variables
    
    # gives relevant properties to the other instance
    def adopt(other)
        other.stack = @stack
        other.output = @output
        other.variables = @variables
    end
    
    def advance
        @pointer.move_bound(@dir, @width, @height)
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
        @stack.get *a
    end
    
    def execute(debug = false, debug_time = 0.5)
        if @field == [[]]
            while true
                self.print_state(debug_time) if debug
            end
        end
        @running = true
        while @running
            self.print_state(debug_time) if debug
            
            cmd = self.current
            if @commands.has_key? cmd
                @commands[cmd].call(self)
            elsif cmd == "@"
                self.advance
                cmd += self.current
                unless @commands.has_key? cmd
                    raise "character `#{cmd}` is not a vaild instruction."
                end
                @commands[cmd].call(self)
            elsif cmd == '"'
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
                @stack.push build
            elsif cmd == "'"
                build = ""
                loop do
                    self.advance
                    break if @pointer.from(@field) == "'"
                    
                    build += self.current
                end
                @stack.push sround build
            elsif cmd == "["    # begin function definition
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
                @stack.push Func.new(build, self)
            elsif cmd =~ /[0-9]/
                @stack.push cmd.to_i
            else
                raise "character `#{cmd}` is not a vaild instruction."
            end
            
            self.advance
        end
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

# execute program

flags = []

flag_arity = {
    "d" => 1,
    "a" => 0
}

other_args = []

i = 0
while i < ARGV.size
    argument = ARGV[i]
    unless nil == (argument =~ /^[-\/]/)
        flag = argument[1 .. argument.size]
        flags.push [flag, ARGV[(i + 1) .. (i + flag_arity[flag])]]
        i += flag_arity[flag]
    else
        other_args.push argument
    end
    i += 1
end

# initialize flags
_debug = false
_debug_time = nil


# activate options
flags.each { |arg|
    flag, options = arg
    if flag == "d"
        _debug = true
        _debug_time = options[0].to_f
    end
}

program = File.read(other_args.shift)

Reticular.new(program, other_args).execute(_debug, _debug_time)