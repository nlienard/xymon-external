#!/usr/bin/perl
########################################
# NLIENARD - 2015-02-23
# Analyze Apache log on the last Hour
# Show top 10 of most frequented IP
# NEED PERL MODULE File::ReadBackwards
########################################
# PBIDAULT - ADDED IP excluded - 2015-06-05

use strict;
use warnings;
use Data::Dumper;
use File::ReadBackwards;

##### Conf to modify ############
my $path = "/var/apache/logs/";
my @vhosts=('www.domain1.com', 'www.domain2.com', 'www.domain3.com', 'www.domain4.com') ;
my $warn = 2000;
my $crit = 3000;
### List of IPs to be excluded of the analysis
# 1.2.3.4 : XXXX
# 1.3.4.5 : YYYY
my @exclude=('1.2.3.4' , '2.3.4.5' );
#######  End COnf ##############

my $TEST="apache_top";
my $COLOR="green";
my $date=`date +%d/%b/%Y:%H -d "1hour ago"`;
chomp($date);
my $date_end=`date +%d/%b/%Y:%H -d "2hour ago"`;
chomp($date_end);

my %total;
my %counts;
my $count=0;
my @html;

push @html, "WARN : $warn - CRIT : $crit<br>";

push @html, "<style type=\"text/css\">";
push @html, "\n
\#top {
        margin: 0 auto;
        padding-right:5px;
        border-width:1px 2px 3px 2px;
        padding:0 10px;
        float:left;
}";
push @html, "
td {
        padding-right:15px;
}

.vhost {
        border:1px solid white;
        padding:3px;
 }
</style>";

foreach my $vhost (@vhosts) {
        my @lines;
        my $log=$path . ${vhost} . "/access_log";
        my $fh = File::ReadBackwards->new($log) or die "can't read file: $!\n";
        while ( defined(my $line = $fh->readline) ) {
            next if $line !~ /$date/;
            my @data = split (' ',$line);
            my $ip = $data[0];
            $ip =~ s/,//;
            next if $ip ~~ @exclude;
            next if $ip =~ "-";
            $counts{$vhost}{$ip}++;
            $total{$vhost}++;
            $count++;
            last if $line =~ /$date_end/;
      }
}

for my $vhost ( reverse sort keys %counts ) {
        push @html, "<div id=top>";
        push @html, "<h3><span class=vhost>$vhost</span></h3>";
        push @html, "<table id=$vhost>";
        my $max=10;
        my $count=0;
        for my $ip ( reverse sort { $counts{$vhost}{$a} <=> $counts{$vhost}{$b} } keys %{ $counts{$vhost} }) {
                use integer;
                my $perc = ( 100 * $counts{$vhost}{$ip} / $total{$vhost} );
                my $color = 'green';
                if ($counts{$vhost}{$ip} >= $warn) {
                       $color = 'yellow';
                }
                if ($counts{$vhost}{$ip} >= $crit) {
                        $color = 'red';
                }
                my $dns=`host -W 5 $ip| awk '{print \$5}'`;
                chomp($dns);
                push @html,  "<tr><td>&$color</td><td>$ip / $dns</td><td>$counts{$vhost}{$ip}</td><td>$perc%</td></tr>\n";
                $count++;
                last if $count eq $max;

        }
        push @html,  "<tr><td>&green</td><td>Total</td><td>$total{$vhost}</td><td>100%</td></tr>\n";
        push @html, "</table></div>";
}

if (grep /&yellow/, @html) { $COLOR="yellow"; }
if (grep /&red/, @html) { $COLOR="red"; }

# FORMAT IT PROPERLY FOR BB...
my $line="status+2d $ENV{MACHINE}.$TEST $COLOR `date` - apache_top looks $COLOR
This led shows the top IP by vhost.

Analyzing Logs Date : $date

EXCLUDED IPs : @exclude

@html
";

system ("$ENV{BB} $ENV{BBDISP} \"$line\"");

##############################
# RRD
#############################
for my $vhost ( reverse sort keys %counts ) {
my $rrd="data $ENV{MACHINE}.trends
[$TEST.$vhost.rrd]
DS:last_hour:GAUGE:600:U:U $total{$vhost}";
system ("$ENV{BB} $ENV{BBDISP} \"$rrd\"");
}
############################
exit 0;
