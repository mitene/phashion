require 'mkmf'

HERE = File.expand_path(File.dirname(__FILE__))
BUNDLE = Dir.glob("#{HERE}/pHash-*.tar.gz").first
BUNDLE_PATH = BUNDLE.gsub(".tar.gz", "")
$CFLAGS = " -x c++ #{ENV["CFLAGS"]}"
$CFLAGS += " -fdeclspec" if RUBY_PLATFORM =~ /darwin/
$includes = " -I#{HERE}/include"
$libraries = " -L#{HERE}/lib -L/usr/local/lib"

mac_os_with_homebrew = RUBY_PLATFORM =~ /darwin/ && system('which brew 2>&1 1>/dev/null')
# Give include/lib paths for macOS using homebrew
# https://github.com/westonplatter/phashion/pull/99
if mac_os_with_homebrew
  prefix = `brew --prefix`.strip
  sqlite_prefix = `brew --prefix sqlite3`.strip
  $includes += " -I#{prefix}/include -I#{sqlite_prefix}/include"
  $libraries += " -L#{prefix}/lib -L#{sqlite_prefix}/lib"
end

$LIBPATH = ["#{HERE}/lib"]
$CFLAGS = "#{$includes} #{$libraries} #{$CFLAGS}"
$LDFLAGS = "#{$libraries} #{$LDFLAGS}"
$CXXFLAGS = ' -pthread'
$CXXFLAGS += $includes if mac_os_with_homebrew

Dir.chdir(HERE) do
  if File.exist?("lib")
    puts "pHash already built; run 'rake clean' first if you need to rebuild."
  else

    puts(cmd = "tar xzf #{BUNDLE} 2>&1")
    raise "'#{cmd}' failed" unless system(cmd)

    # Overwrite outdated config.sub/config.guess scripts that can't recognize modern architectures like `aarch64-apple`.
    # pHash v0.9.6 was released way before Macs with Apple Silicon appeared, so it includes older versions of these scripts.
    # See https://github.com/westonplatter/phashion/pull/100 for more context.
    #
    # You can update these scripts using the following curl commands:
    #   curl -o ext/phashion_ext/config.sub https://git.savannah.gnu.org/cgit/config.git/plain/config.sub
    #   curl -o ext/phashion_ext/config.guess https://git.savannah.gnu.org/cgit/config.git/plain/config.guess
    puts(cmd = "cp ./config.sub #{BUNDLE_PATH}/")
    raise "'#{cmd}' failed" unless system(cmd)

    puts(cmd = "cp ./config.guess #{BUNDLE_PATH}/")
    raise "'#{cmd}' failed" unless system(cmd)

    Dir.chdir(BUNDLE_PATH) do
      puts(cmd = "env CXXFLAGS='#{$CXXFLAGS}' CFLAGS='#{$CFLAGS}' LDFLAGS='#{$LDFLAGS}' ./configure --prefix=#{HERE} --disable-audio-hash --disable-video-hash --disable-shared --with-pic 2>&1")
      raise "'#{cmd}' failed" unless system(cmd)

      puts(cmd = "make || true 2>&1")
      raise "'#{cmd}' failed" unless system(cmd)

      puts(cmd = "make install || true 2>&1")
      raise "'#{cmd}' failed" unless system(cmd)

      puts(cmd = "mv CImg.h ../include 2>&1")
      raise "'#{cmd}' failed" unless system(cmd)
    end

    system("rm -rf #{BUNDLE_PATH}") unless ENV['DEBUG'] or ENV['DEV']
  end

  Dir.chdir("#{HERE}/lib") do
    system("cp -f libpHash.a libpHash_gem.a")
    system("cp -f libpHash.la libpHash_gem.la")
  end
  $LIBS = " -lpthread -lpHash_gem -lstdc++ -ljpeg -lpng -lm"
end

have_header 'sqlite3ext.h'

create_makefile 'phashion_ext'
