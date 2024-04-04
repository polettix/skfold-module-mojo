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
   my $has_authentication = V 'has_authentication';
   $has_db = 1 if $has_authentication;

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
%]has model => \&_new_db_instance;
[% } %]
sub startup ($self) {
   $self->moniker(MONIKER);
   $self->_startup_config
      ->_startup_secrets[% if ($has_db) { %]
      ->_startup_model[% } %][% if ($has_authentication) { %]
      ->_startup_authentication[% } %]
      ->_startup_hooks[% if ($has_minion) { %]
      ->_startup_minion[% } %][% if ($has_controller) { %]
      ->_startup_routes[% } %]
      ;[% if ($has_controller) { %]
   $self->controller_class('[% all_modules.controller_module %]');[% } %]
   $self->log->info('startup complete');
   $self->defaults(layout => 'default');
   return $self;
}

sub _startup_config ($self) {
   my $config = eval { $self->plugin('NotYAMLConfig') } || {};

   # variables with a prefix
   my $prefix = (uc(MONIKER) =~ s{-}{_}rgmxs) . '_';
   for my $key (qw<
         [% if ($has_db) { %]dsn_url[% } %]
         remap_env
      >) {
      my $env_key = $prefix . uc($key);
      $config->{$key} = $ENV{$env_key} if defined $ENV{$env_key};
   }

   # variables to be taken remapped from the environment
   if (defined(my $remaps = $config->{remap_env})) {
      for my $definition (split m{,}mxs, $remaps) {
         my ($key, $env_key) = split m{=}mxs, $definition, 2;
         $env_key = $key unless length($env_key // '');
         $config->{$key} = $ENV{$env_key} if defined $ENV{$env_key};
      }
   }

   $self->conf($config); # WARN: this is really named "conf", NOT "config"
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
sub _startup_model ($self) {
   # FIXME anything to do here?
   return $self;
}
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
[%
      if ($has_authentication) {
%]
sub _startup_authentication ($self) {
   require [% all_modules.authentication_module %];
   my $module = '[% all_modules.authentication_module %]';
   $self->plugin(
      Authentication => {
         load_user     => $module->can('load_user'),
         validate_user => $module->can('validate_user'),
      }
   );

   $self->hook(
      before_render => sub ($c, $args) {
         my $acct = $c->is_user_authenticated ? $c->current_user : undef;
         $c->stash(account => $acct);
         return $c;
      }
   );

   # routes scaffolding
   my $r = $self->routes;
   $r->get('login')->to('authentication#show_login');
   $r->post('login')->to('authentication#do_login');
   $r->get('logout')->to('authentication#do_logout');
   $r->post('logout')->to('authentication#do_logout');
   # FIXME add routes for API login/logout

   # to set authenticated routes, change method "_authenticated_routes"
   my $auth = $r->under('/auth')->to('authentication#check');
   $self->_authenticated_routes($auth);

   # add a final catchall to force anything under /auth to require
   # authentication, even non-existent routes. This avoids leaking info
   # about which authenticated routes are valid and which not.
   $auth->any('*' => sub ($c) { return $c->render(status => 404) });

   return $self;
}

sub _authenticated_routes ($self, $root) {
   $root->get('/')->to('authenticated-basic#root');
}
[%
   }
%]
sub __split_and_decode ($s) { map { b64_decode($_) } split m{\s+}mxs, $s }

sub _startup_hooks ($self) {
   return $self;
}

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
