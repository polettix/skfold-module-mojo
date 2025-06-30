package [% module %];
use Mojo::Base qw< -base -signatures >;

[%
   my $has_db = V('has_db');
   my $pfx_db = $has_db ? '' : '# ';
%]
[%= $pfx_db %]use MojoX::MojoDb;

[%= $pfx_db %]has 'db_url';
[%= $pfx_db %]has wmdb => sub ($s) { MojoX::Db->new(db_url => $s->db_url) };
[%= $pfx_db %]sub mdb ($self) { my $w = $self->wmdb // return; $w->mdb }
[%= $pfx_db %]sub  db ($self) { my $w = $self->wmdb // return; $w->db  }

has 'authentication_options';
has authentication => \&_build_authn;
sub _build_authn ($self) {
   my %opts = ($self->authentication_options // {})->%*;
   require MojoX::Authentication::Model;
   return MojoX::Authentication::Model->new(%opts, model => $self);
}

has 'authorization_options';
has authorization => \&_build_authz;
sub _build_authz ($self) {
   my %opts = ($self->authorization_options // {})->%*;
   require [% all_modules.model_authz_module %];
   return [% all_modules.model_authz_module %]->new(%opts, model => $self);
}

1;
