package [% module %];
use strict;
use warnings;
use experimental 'signatures';
no warnings 'experimental::signatures';

sub sub_register ($plugin, $app, $config) {
   my $minion = $app->minion;
   $minion->add_task('basic/example' => \&example);
   return;
}

sub example ($job) {
   $job->app->log->info('Howdy!');
   return;
}

1;
