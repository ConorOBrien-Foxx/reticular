load "funcs.rb"

class String
    def quote
        '"' + self + '"'
    end
end

def sround(item)
    if item.is_a? String
        sround item.to_f
    elsif item.is_a? Float
        item == item.to_i ? item.to_i : item
    elsif item.is_a? Fixnum
        item
    else
        nil
    end
end

def highlight(text)
    "\e[4m\e[1m\e[36m#{text}\e[0m\e[0m\e[0m"
end

def clear
    system "clear" or system "cl"
end

def mutli_line_input
    string = ""
    until (line = $stdin.gets).chomp.empty?
        string += line
    end
    return string
end

def pretty(*args)
    str = ""
    args.each do |item|
        if item.kind_of? Array
            str += "[ #{ item.map { |el| pretty(el) }.join(", ") } ]"
        elsif item.kind_of? String
            str += item.quote
        # elsif item.kind_of? Fixnum
        else
            str += item.to_s
        end
        str += " " unless item == args.last
    end
    str
end

def pputs(*args)
    puts pretty(*args)
end

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

def nary(n, sym, f_map)
    lambda { |instance|
        top = instance.stack.get(n)
        types = top.map { |item| item.class }
        func = nil
        f_map.each do |dest_type, f|
            i = -1
            valid = dest_type.all? { |d_t| d_t == :any || d_t == types[i += 1] }
            if valid
                func = f
            end
        end
        
        if func == nil
            raise "operator #{sym} does not have behaviour for types [#{types.join(", ")}]"
        end
        instance.stack.push func.call(*top)
    }
end

def binary(*args)
    nary(2, *args)
end

def unary(*args)
    nary(1, *args)
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
        "+"  => binary("+", {
            [:any, :any] => lambda { |x, y| x + y },
        }),
        "*"  => binary("*", {
            [:any, :any] => lambda { |x, y| x * y },
        }),
        "%"  => binary("%", {
            [Fixnum, Fixnum]   => lambda { |x, y| x.to_f / y.to_f },
            [Fixnum, Float]    => lambda { |x, y| x.to_f / y },
            [Float, Fixnum]    => lambda { |x, y| x / y.to_f },
            [Float, Float]     => lambda { |x, y| x / y },
        }),
        ":"  => binary(":", {
            [:any, :any]   => lambda { |x, y| (x.to_f / y.to_f).to_i }
        }),
        "~"  => lambda { |instance| instance.get(2).reverse.each {|e| instance.stack.push e} },
        "a"  => lambda { |instance|
            top = instance.stack.pop
            arg = instance.args[top]
            unless defined? arg
                raise "argument #{top} does not exist."
            end
            instance.push arg
        },
        "c"  => unary("c", {
            [Fixnum] => lambda { |x| x.chr },
        }),
        "A"  => lambda { |instance| instance.push instance.args },
        "f"  => unary("n", {
            [:any] => lambda { |x| x.to_f }
        }),
        "i"  => lambda { |instance| instance.push $stdin.gets.chomp },
        "I"  => lambda { |instance| instance.push mutli_line_input },
        "n"  => unary("n", {
            [:any] => lambda { |x| sround x }
        }),
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
        "s"  => unary("s", {
            [:any] => lambda { |x| x.to_s }
        }),
    }
    
    def initialize(code, args)
        @dir = Coordinate.new(1, 0)
        @args      = args
        @stack     = Stack.new
        @output    = ""
        @running   = false
        @pointer   = Coordinate.new(0, 0)
        
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
    
    attr_accessor :field
    attr_accessor :dir
    attr_accessor :pointer
    attr_accessor :width
    attr_accessor :height
    attr_accessor :stack
    attr_accessor :output
    attr_accessor :args
    
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
            if @@commands.has_key? cmd
                @@commands[cmd].call(self)
            elsif cmd == "@"
                self.advance
                cmd += self.current
                unless @@commands.has_key? cmd
                    raise "character `#{cmd}` is not a vaild instruction."
                end
                @@commands[cmd].call(self)
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