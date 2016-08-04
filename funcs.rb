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
                    return false
                end
            }
            true
        end
    end
    
    @@mem_nth_prime = {
        0 => 2,
        1 => 3,
        2 => 5
    }
    def F.nth_prime(n)
        # TODO: implement
    end
end

