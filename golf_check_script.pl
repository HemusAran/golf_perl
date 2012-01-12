#! /usr/bin/perl

use strict;
use utf8;
use warnings;

use FindBin ();
use Encode ();
use LWP::UserAgent ();
use HTML::TreeBuilder ();

binmode(STDOUT, ":utf8");

my $PERL = '/usr/bin/perl';
my $ARGC = scalar(@ARGV);

my $MAIN_PL = 'main.pl';
my $INPUT_TEXT = 'input';
my $OUTPUT_TEXT = 'output';

### main
&main();
exit(0);
###

sub main {
	if ($ARGC == 0) { #optionが無い場合は usage 出力
		&usage();
	}

	# make
	if ($ARGV[0] eq 'make' || $ARGV[0] eq 'm') {
		&make();
		return;
	}

	# perl実行
	if ($ARGV[0] =~ /\d/) {
		&section($ARGV[0]);
		return;
	}

	# all実行
	if ($ARGV[0] eq 'all') {
		&all_section();
		return;
	}

	&usage();
}

### 引数のURLからdirectory, input/outputのファイルを作成
sub make {
	if ($ARGC != 2) {
		print 'ERROR : make の引数にURLがありません。',"\n";
		return;
	}

	my $url = $ARGV[1];
	my $user_agent = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_3; ja-jp) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16';

	if ($url !~ /golf.shinh.org/) {
		print 'golf.shinh.org のURLではありません。',"\n";
		return;
	} else {
		# ディレクトリの作成、移動
		$url =~ /\?/;
		my $dir_path = $';
		if (! -d $dir_path) {
			mkdir($dir_path);
		}
		chdir($dir_path) or die $!;
	}

	# HTML取得
	my $ua = LWP::UserAgent->new('agent' => $user_agent);
	my $res = $ua->get($url);
	my $content = $res->content;

	&make_io_text(0, $content);
	&make_io_text(1, $content);

	# input/output 作成
	sub make_io_text {
		my ($search, $content) = @_;

		my $search_str = $search==0?'<h2>Sample input':'<h2>Sample output';
		my $file = $search==0?$INPUT_TEXT:$OUTPUT_TEXT;

		for (my $i=1, my $index=0; $i<=3; $i++, $index++) {
			$index = index($content, $search_str, $index);
			if ($index == -1) {
				last;
			}

			my $input_start = index($content, '<pre>', $index) + length'<pre> ';
			my $input_end   = index($content, '</pre>', $index);
	
			my $input_text = '';
			$input_text = substr($content, $input_start, $input_end-$input_start);
			$input_text =~ s/&gt;/>/g;
			$input_text =~ s/&lt;/</g;
	
			# ファイル作成
			my $file_name = "$file$i.txt";
			open(FILE, ">$file_name") or die $!;
			print FILE $input_text;
			close(FILE);
		}
	}

	# main.pl を作成
	open(FILE, ">$MAIN_PL") or die $!;
	print FILE "\n\n\n# $url";
	close(FILE);
}

### 
sub all_section {
	my @files = glob("$OUTPUT_TEXT?.txt");
	my $num = scalar(@files);

	for (my $i=1; $i<=$num; $i++) {
		print "----- section $i -----\n";
		&section($i);
	}
}

### 
sub section {
	my ($option) = @_;
	my $num = 0;
	if ($option =~ /\d/) {
		$num = $&;
	}

	# perlを実行して出力取得
	my $golf_output = `$PERL $MAIN_PL $INPUT_TEXT$num.txt`;
	{
		Encode::_utf8_on($golf_output);
		$golf_output =~ s/\n+$/\n/; # 最後の複数改行は消す
		if ($golf_output !~ /\n/) { # 改行が1つもない場合は加える
			$golf_output .= "\n";
		}
		#chomp($golf_output);
	}

	# オプションo - 出力
	if ($option =~ /o/) {
		print $golf_output;
		return;
	}

	# 出力チェック。不一致があれば出力
	my $diff_count = 0;
	my @output = split("\n", $golf_output);

	# 出力が無い場合にダミーデータ挿入
	if (scalar(@output) == 0) {
		$output[0] = "";
	}

	{
		open(FILE, "<:utf8", "$OUTPUT_TEXT$num.txt") or die $!;
		my @answer = <FILE>;
		chomp(@answer);
		close(FILE);

		my $length = scalar(@output);
		for (my $i=1; $i<=$length; $i++) {
			if ($output[$i-1] ne $answer[$i-1]) {
				print "$i-----\n$output[$i-1]\n$answer[$i-1]\n";
				$diff_count++;
			}
		}
	}

	# 全て一致していたらソースコードを出力
	if ($diff_count == 0) {
		&code_output();
	}
}

### ソースコードからコメントアウトや改行を削除して出力
sub code_output {
	open(FILE, "<:utf8", $MAIN_PL);
	my @source = <FILE>;
	close(FILE);

	# header
	my $head = '';
	if ($source[0] =~ /^#!/) {
		$head = shift(@source);
	}

	# 改行、コメントアウトの廃除（コード中に意味のある改行がある場合消してしまうため注意）
	my @short = ();
	my $count = 0;
	foreach my $line (@source) {
		$line =~ s/(?<!\$)#.*$|\t|\n//g;
		if (length $line == 0) {
			next;
		}

		$short[$count] = $line;
		$count++;
	}

	my $short_code = $head.join("", @short);
	my $size = length($short_code);

	# calc Statistics
	my $binary = -1;
	for my $byte (ord split(//, $short_code)) {
		if (32<$byte && $byte<127) {
			$binary++;
		}
	}

	my $temp_alnum = $short_code;
	my $alnum = $temp_alnum =~ s/[a-zA-Z0-9]//g;

	my $temp_symbol = $short_code;
	my $symbol = $temp_symbol =~ s/[!\"\#\$%&'()*+,-.\/:;<=>?@[\\\]^_`{|}~]//g;

	# 出力
	print "### size : ",$size,"Byte | ",$binary,"B / ",$alnum,"B / ",$symbol,"B","\n";
	print $short_code,"\n\n";
}

### error
sub usage {
	my $this_dir = $FindBin::Bin;
	my $help_file = 'README';

	open(FILE, "<:utf8", "$this_dir/$help_file") or die $!;
	while (my $line = <FILE>) {
		if ($line !~ /^#/) {
			print $line;
		}
	}
	close(FILE);

	exit(0);
}

