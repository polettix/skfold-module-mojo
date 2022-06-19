package [% module %];
use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $config) {
   my $minion = $app->minion;
   $minion->add_task('some/example' => \&example);
   return;
}

sub example ($job) {
   $job->app->log->info('Howdy!');
   return;
}

1;
