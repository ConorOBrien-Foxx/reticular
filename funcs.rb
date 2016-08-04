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
