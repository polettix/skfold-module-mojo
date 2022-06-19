package [% main_module %];
use v5.24;
use Mojo::Base 'Mojolicious', -signatures;
use Ouch ':trytiny_var';
use Try::Catch;
use Mojo::Util qw< b64_decode >;
[%
   my $has_db = V 'has_db';
   my $has_minion = V 'has_minion';
   my $has_controller = V 'has_controller';

   if ($has_controller) {
%]use [% all_modules.controller_module %];
[% } %]
use constant MONIKER => '[%=
   (my $moniker = lc V("main_module")) =~ s{::}{-}gmxs;
   $moniker;
%]';
use constant DEFAULT_SECRETS => '[%=
   use MIME::Base64 "encode_base64";
   encode_base64(time() . "-" . rand(), '');
%]';

has 'conf';
[%
   if ($has_db) {
%]has db => \&_new_db_instance;
[% } %]
sub startup ($self) {
   $self->moniker(MONIKER);
   $self->_startup_config[% if ($has_minion) { %]
      ->_startup_minion[% } %][% if ($has_controller) { %]
      ->_startup_routes[% } %]
      ->_startup_secrets;[% if ($has_controller) { %]
   $self->controller_class('[% all_modules.controller_module %]');[% } %]
   $self->log->info('startup complete');
   return $self;
}

sub _startup_config ($self) {
   my $config = eval { $self->plugin('NotYAMLConfig') } || {};
   my $prefix = (uc(MONIKER) =~ s{-}{_}rgmxs) . '_';
   for my $key (qw<
         [% if ($has_db) { %]dsn[% } %]
      >) {
      my $env_key = $prefix . uc($key);
      $config->{$key} = $ENV{$env_key} if defined $ENV{$env_key};
   }
   $self->conf($config);
   return $self;
}
[%
   if ($has_db) {
%]
sub _dsn ($self) { $self->conf->{dsn} // ouch 500, 'no DSN set' }
sub _db_technology ($self) {
   return $self->_dsn =~ m{postgres}imxs ? 'Pg' : 'SQLite';
}
sub _db_class ($self) { 'Mojo::' . $self->_db_technology }
sub _new_db_instance ($self) { $self->_db_class->new($self->_dsn) }
[%
      if ($has_minion) {
%]
sub _startup_minion ($self) {
   $self->plugin(Minion => { $self->_db_technology => $self->_dsn });
   $self->plugin('Minion::Admin');
   $self->plugin('[% all_modules.minion_module %]');
   return $self;
}
[%
      }
   }
%]
sub __split_and_decode ($s) { map { b64_decode($_) } split m{\s+}mxs, $s }

sub _startup_secrets ($self) {
   my $config = $self->conf;
   my @secrets =
       defined $ENV{SECRETS}      ? __split_and_decode($ENV{SECRETS})
     : defined $config->{secrets} ? $config->{secrets}->@*
     :                              __split_and_decode(DEFAULT_SECRETS);
   $self->secrets(\@secrets);
   return $self;
} ## end sub _startup_secrets
[%
   if ($has_controller) {
%]
sub _startup_routes ($self) {
   my $r = $self->routes;
   $r->any('/')->to('basic#root');
   return $self;
}
[% } %]
1;
