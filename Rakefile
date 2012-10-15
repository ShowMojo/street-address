require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test

desc "Filter an input file of addresses into a good and bad files. Usage: [input] [good] [bad]"
task :filter_file do
  $:.unshift File.join(File.dirname(__FILE__), "lib")
  require 'benchmark'
  require 'street_address'
  require 'json'
  
  unless ARGV.length == 4
    puts "Expected format: `rake filter_file addresses_in.txt good_addresses_out.txt bad_addresses_out.txt`"
  else
    parser = StreetAddress::US.new(:street_only => true)
    input = File.read(ARGV[1]).split("\n")
    good_out, bad_out = ARGV[2..3].map{|p| File.open p, "w" }
    count, good, bad, start = 0, 0, 0, Time.now
    lines = input.count
    
    puts # progress will go on this line

    bm = Benchmark.measure do
      input.each do |address_input|
        address_input = $1 if address_input =~ /^"(.*)"$/
        address_obj = parser.parse(address_input)
        if address_obj
          good_out.write "#{address_input}\n"
          good += 1
        else
          bad_out.write "#{address_input}\n"
          bad += 1
        end
        count += 1
        if count % 100 == 0
          good_out.flush; bad_out.flush
          print "\r%6.2f %" % ((count/lines.to_f) * 100)
        end
      end
      print "\r100.00 %\n\n"
    end
    
    good_out.close
    bad_out.close

    elapsed = Time.now - start
    puts "Processed #{count} addresses in #{elapsed.round(2)}s (#{(count/elapsed).round(2)} addresses/second)"
    puts "  Good Addresses: " + sprintf("%#{lines.to_s.length}d", good)
    puts "  Bad  Addresses: " + sprintf("%#{lines.to_s.length}d", bad)
    puts
    puts "      user     system      total        real"
    puts bm
  end
end
