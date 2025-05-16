#!/usr/bin/env perl
[%
   my %has = map { $_ => V("has_$_") }
      qw< authentication controller db minion >;
   my %pfx = map { $_ => ($has{$_} ? '' : '# ') }
      qw< db minion authentication >;
%]
package [% main_module %];
use v5.24;
use Mojo::Base qw< Mojolicious -signatures >;
use Ouch qw< :trytiny_var >;
use Try::Catch;
use Storable qw< dclone >;
use Mojo::Util qw< b64_decode >;
[%= $pfx{controller} %]use [% all_modules.controller_module %];
use [% all_modules.model_module %];

use constant MONIKER => '[%=
   (my $moniker = lc V("main_module")) =~ s{::}{-}gmxs;
   $moniker;
%]';

use constant DEFAULTS => {
   CONFIG => {},
   DATABASE_URL => 'sqlite:./tmp/test.db',
   SECRETS => '[%=
      use MIME::Base64 "encode_base64";
      encode_base64(time() . "-" . rand(), '');
   %]',
   SECRETS => ['FIXME'],
   HARDCODED_AUTHENTICATION_DB => [
      { name => foo => secret => 123  },
      { name => bar => secret => 456  },
      { name => baz => secret => 789  },
      { name => galook => secret => 0 },
   ],
};

has 'model';

sub startup ($self) {
   $self->moniker(MONIKER);
   $self->defaults(layout => 'default');

   $self->_startup_config;
   $self->_startup_secrets;
   $self->_startup_model;

[% if ($has{minion}) { %]
   $self->_startup_minion;
[% } %]

[% if ($has{controller}) { %]
   $self->_startup_hooks;
   $self->_startup_routes;
   $self->controller_class('[% all_modules.controller_module %]');
[% } %]

[% if ($has{authentication}) { %]
   $self->_startup_authentication;
[% } %]

   $self->log->info('startup complete');
   return $self;
}

sub _startup_config ($self) {
   my $defaults_for = DEFAULTS;
   my $config =
      $self->plugin(JSONConfig => { default => $defaults_for->{CONFIG}});

   # variables with a prefix
   my $prefix = (uc(MONIKER) =~ s{-}{_}rgmxs) . '_';
   my @prefixed = (
      qw< remap_env secrets >,
      [%= $pfx{db} %]'dsn_url',
   );
   for my $key (@prefixed) {
      my $env_key = $prefix . uc($key);
      $config->{$key} = $ENV{$env_key} if defined $ENV{$env_key};
   }

   # variables without a prefix
   $config->{database_url} //=
     $config->{dsn_url} // $defaults_for->{DATABASE_URL};
   $config->{secrets} //= $defaults_for->{SECRETS};

   # variables to be taken remapped from the environment
   if (defined(my $remaps = $config->{remap_env})) {
      for my $definition (split m{,}mxs, $remaps) {
         my ($key, $env_key) = split m{=}mxs, $definition, 2;
         $env_key = $key unless length($env_key // '');
         $config->{$key} = $ENV{$env_key} if defined $ENV{$env_key};
      }
   }

   return $self;
}

# Set secrets. They might come in array or encoded string form, in which
# case we have to split the string and decode it.
sub _startup_secrets ($self) {
   my $secrets = $self->config->{secrets};
   $secrets = [ map { b64_decode($_) } split m{\s+}mxs, $secrets ]
      unless ref($secrets);
   $self->secrets($secrets);
   return $self;
} ## end sub _startup_secrets

sub _startup_model ($self) {
   my $config = $self->config;
   my $model = [% all_modules.model_module %]->new(
      [%= $pfx{db} %]db_url => $self->config->{database_url},

      authentication_options => {

         # order of providers matter, first ones are checked first.
         # Pass:
         # - an object instance
         # - a sub reference
         # - a hash ref with keys (instance) or (class, args). Optionally
         #   set a name with key name
         # If key name is present in hash, or instance support the 'name'
         # method, a name is set for later retrieval of the instance by
         # method instance_for($name).
         # Some examples below...
         providers => [
            {
               name  => 'hashy',
               class => '[% all_modules.model_authn_hash_module %]',
               args  => [
                  db => DEFAULTS->{HARDCODED_AUTHENTICATION_DB},

                  # set to true if secrets in db already hashed
                  secrets_already_hashed => 0,
               ],
            },
            {
               name  => 'db',
               class => '[% all_modules.model_authn_db_module %]',
               args  => [],
            },
            # above also:
            # sub ($model) {
            #    require [% all_modules.model_authn_db_module %];
            #    [% all_modules.model_authn_db_module %]->create(
            #       model => $model,
            #       name => 'db',
            #    );
            # },
         ],

      },

   );
   $self->model($model);

   # do anything that's needed for initialization here...
   $model->wmdb->init($self->moniker);

   return $self;
}

sub _startup_minion ($self) {
   my $wmdb = $self->model->wmdb;
   $self->plugin(Minion => { $wmdb->mdb_engine => $wmdb->db_url });
   $self->plugin('Minion::Admin');
   $self->plugin('[% all_modules.minion_module %]');
   return $self;
}


[%
   if ($has{controller}) {
%]
sub _startup_hooks ($self) {
   return $self;
}

sub _startup_authentication ($self) {
   my $authn = $self->model->authentication;
   $self->plugin(
      Authentication => {
         load_user     => sub ($a, $x) { $authn->load_user($x)     },
         validate_user => sub ($c, @A) { $authn->validate_user(@A) },
      },
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
########################################################################
#
# Routes, where all the fun happens!
#
# By default, routes are private and subject to authentication. The
# exception set by default is everything under '/public', including
# '/public/auth' to cope with login/logout in locally managed accounts
#
sub _startup_routes ($self) {
   my $root = $self->routes;

   my $public_root = $root->any('/public')->name('public_root');
   my $protected_root = $root->under(
      '/' => sub ($c) {
         if ($c->is_user_authenticated) {
            $c->stash(is_user_authenticated => 1);
            return 1;
         }
         $c->log->debug('not authenticated, bouncing to public home');
         $c->stash(is_user_authenticated => 0);
         $c->redirect_to('public_root');
         return 0;
      }
   );

   $self->_public_routes($public_root)
      ->_authentication_routes($public_root->any('/auth'))
      ->_protected_routes($protected_root)
      ->_default_to_404($root);

   return $self;
}

# Routes for local authentication (trivial/db)
sub _authentication_routes ($self, $root) {
   my %ctr = (controller => 'Public::Authentication');
   $root->get('/login')->to(%ctr, action => 'show_login');
   $root->post('/login')->to(%ctr, action => 'do_login');
   $root->get('/logout')->to(%ctr, action => 'do_logout');
   $root->post('/logout')->to(%ctr, action => 'do_logout');
   return $self;
}

sub _default_to_404 ($self, $root) {
   my $nf = sub ($c) {$c->render(template => 'not_found', status => 404)};
   $root->any($_ => $nf) for qw< * / >;
   return $self;
}

############## MAIN BUSINESS LOGIC ########################################
sub _public_routes ($self, $root) {
   $root->get('/')->to('public#root');
   return $self;
}

sub _protected_routes ($self, $root) {
   $root->get('/')->to('protected#root');
   $root->get('/example')->to(controller => 'Protected::Example',
      action => 'root');
   return $self;
}

[% } %]
1;
