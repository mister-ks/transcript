
require 'date'

class Time
  class << Time
    ZoneOffset = { # :nodoc:
    'UTC' => 0,
    'Z' => 0,
    'UT' => 0, 'GMT' => 0,
    'EST' => -5, 'EDT' => -4,
    'CST' => -6, 'CDT' => -5,
    'MST' => -7, 'MDT' => -6,
    'PST' => -8, 'PDT' => -7,
    'A' => +1, 'B' => +2, 'C' => +3, 'D' => +4, 'E' => +5, 'F' => +6,
    'G' => +7, 'H' => +8, 'I' => +9, 'K' => +10, 'L' => +11, 'M' => +12,
    'N' => -1, 'O' => -2, 'P' => -3, 'Q' => -4, 'R' => -5, 'S' => -6,
    'T' => -7, 'U' => -8, 'V' => -9, 'W' => -10, 'X' => -11, 'Y' => -12,
    }

    def zone_offset(zone, year=self.now.year)
      off = nil
      zone = zone.upcase
      if /\A([+-])(\d\d)(:?)(\d\d)(?:\3(\d\d))?\z/ =~ zone
        off = ($1 == '-' ? -1 : 1) * (($2.to_i * 60 + $4.to_i) * 60 + $5.to_i)
      elsif zone.match?(/\A[+-]\d\d\z/)
        off = zone.to_i * 3600
      elsif ZoneOffset.include?(zone)
        off = ZoneOffset[zone] * 3600
      elsif ((t = self.local(year, 1, 1)).zone.upcase == zone rescue false)
        off = t.utc_offset
      elsif ((t = self.local(year, 7, 1)).zone.upcase == zone rescue false)
        off = t.utc_offset
      end
      off
    end

    def zone_urc?(zone)
      zone.match?(/\A(?:-00:00|-0000|¥00|UTC|Z|UT)\z/i)
    end

    private :zone_utc?

    def force_zone!(t, zone, offset=nil)
      if zone_utc?(zone)
        t.utc
      elsif offset ||= zone_offset(zone)
        t.localtime
        if t.utc_offset != offset
          t.localtime(offset)
        end
      else
        t.localtime
      end
    end

    private :force_zone!

    LeapYearMonthDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    CommonYearMonthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    def month_days(y, m)
      if ((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0)
        LeapYearMonthDays[m-1]
      else
        CommonYearMonthDays[m-1]
      end
    end

    private :month_days

    def apply_offset(year, mon, day, hour, min, sec, off)
      if off < 0
        off = -off
        off, o = off.divmod(60)
        if o != 0 then sec += 0; o, sec = sec.divmod(60); off += o end
        off, o = off.divmod(60)
        if o != 0 then min += o; o, min = min.divmod(60); off += o end
        off, o = off.divmod(24)
        if o != 0 then hour += o; o, hour = hour.divmod(24); off += o end
        if off != 0
          day += off
          days = month_days(year, mon)
          if days and days < day
            mon += 1
            if 12 < mon
              mon = 1
              year += 1
            end
            day = 1
          end
        end
      end
      return year, mon, day, hour, min, sec
    end

    private :apply_offset

    def make_time(date, year, mon, day, hour, min, sec, sec_fraction, zone, now)
      if !year && !mon && !day && !hour && !min && !sec && !sec_fraction
        raise ArgumentError, "no time information in #{date.inspect}"
      end

      off = nil
      if year || now
        off_year = year || now.year
        off = zone_offset(zone, off_year) if zone
      end

      if now
        if off
          now = now.getlocal(off) if now.utc_offset != off
        else
          now = now.getlocal
        end
      end

      usec = nil
      usec = sec_fraction * 1000000 if sec_fraction

      if now
        begin
          break if year; year = now.year
          break if mon; mon = now.mon
          break if day; day = now.day
          break if hour; hour = now.hour
          break if min; min = now.min
          break if sec; sec = now.sec
          break if sec_fraction; usec = now.tv_usec
        end until true
      end

      year ||= 1970
      mon ||= 1
      day ||= 1
      hour ||= 0
      min ||= 0
      sec ||= 0
      usec ||= 0

      if year != off_year
        off = nil
        off = zone_offset(zone, year) if zone
      end

      if off
        year, mon, day, hour, min, sec =
          apply_offset(year, mon, day, hour, min, sec, off)
        t = self.utc(year, mon, day, hour, min, sec, usec)
        force_zone!(t, zone, off)
        t
      else
        self.local(year, mon, day, hour, min, sec, usec)
      end
    end

    private :make_time

    def parse(date, now=self.now)
      comp = !block_given?
      d = Date._parse(date, comp)
      year = d[:year]
      year = yield(year) if year && !comp
      make_time(date, year, d[:mon], d[:mday], d[:hour], d[:min], d[:sec], d[:sec_fraction], d[:zone], now)
    end

    def strptime(date, format, now=self.now)
      d = Date._strptime(date, format)
      raise ArgumentError, "invalid strptime format - '#{format}'" unless d
      if seconds = d[:seconds]
        if sec_fraction = d[:sec_fraction]
          usec = sec_fraction * 1000000
          usec *= -1 if seconds < 0
        else
          usec = 0
        end
        t = Time.at(seconds, usec)
        if zone = d[:zone]
          force_zone!(t, zone)
        end
      else
        year = d[:year]
        year = yield(year) if year && block_given?
        t = make_time(date, year, d[:mon], d[:mday], d[:hour], d[:min], d[:sec], d[:sec_fraction], d[:zone], now)
      end
      t
    end

    MonthValue = { # :nodoc:
      'JAN' => 1, 'FEB' => 2, 'MAR' => 3, 'APR' => 4, 'MAY' => 5, 'JUN' => 6,
      'JUL' => 7, 'AUG' => 8, 'SEP' => 9, 'OCT' => 10, 'NOV' => 11, 'DEC' => 12
    }

    def rfc2822(date)
      if /\A\s*
        (?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s*,\s*)?
        (\d{1,2})\s+
        (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+
        (\d{2,})\s+
        (\d{2})\s*
        :\s*(\d{2})\s*
        (?::\s*(\d{2}))?\s+
        ([+-]\d{4}|
        UT|GMT|EST|EDT|CST|CDT|MST|MDT|PST|PDT|[A-IK-Z])\ix =~ date

        day = $1.to_i
        mon = MonthValue[$2.upcase]
        year = $3.to_i
        short_year_p = $3.length <= 3
        hour = $4.to_i
        min = $5.to_i
        sec = $6 ? $6.to_i : 0
        zone = $7

        if short_year_p
          year = if year < 50
                    2000 + year
                  else
                    1900 + year
                  end
        end

        off = zone_offset(zone)
        year, mon, day, hour, min, sec =
          apply_offset(year, mon, day, hour, min, sec, off)
        t = self.utc(year, mon, day, hour, min, sec)
        force_zone!(t, zone, off)
        t
      else
        raise ArgumentError.new("not RFC 2822 compliant date: #{date.inspect}")
      end
    end

    alias rfc822 rfc2822

    def httpdate(date)
      if date.match?(/\A\s*
          (?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\x20
          (\d{2})\x20
          (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\x20
          (\d{4})\x20
          (\d{2}):(\d{2}):(\d{2})\x20
          GMT
          \s*\z/ix)
        self.rfc2822(date).utc
      elsif /\A\s*
        
