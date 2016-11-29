require "io/console"

Infinity = Float::INFINITY  # very important line to fix a very grave mistake

class String
    def quote
        '"' + self + '"'
    end
end

class Regexp
    def body
        /(<=\/).+(?=\/.*$)/.match self.inspect
    end
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
    
    def -@
        [@x, @y]
    end
    
    attr_accessor :x
    attr_accessor :y
end

class Stack < Array
    def top
        self[-1]
    end
    
    def top=(v)
        super.pop
        super.push v
    end
    
    def pop(*args)
        return super || 0 if args.empty?
        n = args.shift
        unless args.empty?
            raise ArgumentError.new "wrong number of arguments " +
            "(given #{args.size + 1}, expected 1)"
        end
        [*([0] * n), *super(n)][-n..-1]
    end
end

def sround(item)
    if item.is_a? String
        item =~ /^[-0-9.]+$/ && sround(item.to_f)
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

def all_input
    input = ""
    loop do
        line = $stdin.gets
        break unless $stdin.tty? ? line && line.chomp != "\x04" : line
        input += line
    end
    input
end

def get_char
    val = STDIN.getch
    exit(1) if val === "\x03"
    val
end

def constant(v)
    lambda { v }
end

def pretty(item, d = 0)
    return item.class if d > 5
    str = ""
    if item.kind_of? Array
        str += "[ #{ item.map { |el| pretty(el, d + 1) }.join(", ") } ]"
    elsif item.kind_of? String
        str += item.quote
    elsif item.kind_of? Hash
        str += "{"
        item.each { |k, v|
            str += "#{pretty(k, d + 1)} => #{pretty(v, d + 1)},"
        }
        str += "}"
    # elsif item.kind_of? Fixnum
    elsif item == nil
        str += "nil"
    else
        str += item.to_s
    end
    str
end

def pputs(*args)
    puts args.map {|item| pretty item}
end

def falsey?(value)
    begin
        return value == false || value == 0 || value == nil || value.empty?
    rescue
        return false
    end
end

def bool_to_i(x)
    (falsey? x) ? 0 : 1
end

module F
    @@mem_is_prime = {
        1 => false,
        2 => true,
        3 => true,
        4 => false,
        5 => true,
        6 => false
    }
    def F.is_prime?(n)
        if @@mem_is_prime.has_key? n
            return @@mem_is_prime[n]
        elsif n < 1
            return false
        else
            (2 .. (Math.sqrt n).to_i).each { |i|
                if n % i == 0
                    return @@mem_is_prime[n] = false
                end
            }
            @@mem_is_prime[n] = true
        end
    end
    
    def F.primes
        Enumerator.new do |enum|
            i = 2
            while true
                enum.yield i
                i += 1
                until F.is_prime? i
                    i += 1
                end
            end
        end
    end
    
    @@mem_nth_prime = {}
    def F.nth_prime(n)
        if @@mem_nth_prime.has_key? n
            return @@mem_nth_prime[n]
        else
            m = n
            gen = F.primes
            c = 2
            while m >= 0
                m -= 1
                c = gen.next
            end
            c
        end
    end
end