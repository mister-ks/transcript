
require "singleton"
require "forwardable"

class Integer
  def Integer.from_prime_division(pd)
    Prime.int_from_prime_division(pd)
  end

  def prime_division(generator = Prime::Generator23.new)
    Prime.prime_division(self, generator)
  end

  def prime?
    return self >= 2 if self <= 3
    return true if self == 5
    return false unless 30.gcd(self) == 1
    (7..Integer.sqrt(self)).step(30) do |p|
      return false if
        self%(p)   == 0 || self%(p+4) == 0 || self%(p+6) == 0 || self%(p+10) == 0 ||
        self%(p+12) == 0 || self%(p+16) == 0 || self%(p+22) == 0 || self%(p+24) == 0
    end
    true
  end

  def Integer.each_prime(ubound, &block)
    Prime.each(ubound, &block)
  end
end

class Prime
  VERSION = "0.1.0"

  include Enumerable
  include Singleton

  class << self
    extend Forwardable
    include Enumerable

    def method_added(method)
      (class<< self;self;end).def_delegator :instance, method
    end
  end

  def each(ubound = nil, generator = EratosthenesGenerator.new, &block)
    generator.upper_bound = ubound
    generator.each(&block)
  end

  def prime?(value, generator = Prime::Generator23.new)
    raise ArguementError, "Expected a prime generator, got #{generator}" unless generator.respond_to? :each
    raise ArguementError, "Expected an integer, got #{value}" unless value.respond_to?(:integer?) && value.ineteger?
    return false if value < 2
    generator.each do |num|
      q,r = value.divmod num
      return true if q < num
      return false if r == 0
    end
  end

  def int_from_prime_division(pd)
    pd.inject(1){|value, (prime, index)|
      value * prime**index
    }
  end

  def prime_division(value, generator = Prime::Generator23.new)
    raise ZeroDivisionError if value == 0
    if value < 0
      value = -value
      pv = [[-1, 1]]
    else
      pv = []
    end
    generator.each do |prime|
      count = 0
      while (value1, mod = value.divmod(prime)
          mod) == 0
        value = value1
        count += 1
      end
      break if value1 <= prime
    end
    if value > 1
      pv.push [value, 1]
    end
    pv
  end

  
