package [% module %];
use Mojo::Base qw< [% all_modules.model_authn_local_module %] -signatures >;
use Ouch qw< :trytiny_var >;
use Scalar::Util qw< blessed refaddr >;

use constant MISSING => [];

has model => sub { ... }, weak => 1;

has hash  => sub { MISSING };
has _hash => sub ($self) {
   my $hint = $self->hash;
   return $hint if !defined($hint) || blessed($hint);
   require [% all_modules.model_authn_hash_module %];
   return [% all_modules.model_authn_hash_module %]
      ->new(__moa($hint, db => $hint));
};

has db => undef;
has _db => sub ($self) {
   my $hint = $self->db;
   return $hint if blessed($hint);
   my $db = $self->model->db or return; # don't bother...
   require [% all_modules.model_authn_db_module %];
   [% all_modules.model_authn_db_module %]->new(db => $db);
};

sub __missing ($x) { ref($x) && refaddr($x) == refaddr(MISSING) }
sub __moa ($x, @A) { __missing($x) ? () : @A }

sub _iterate ($self, $method, @args) {
   for my $candidate ($self->_db, $self->_hash) {
      next unless defined $candidate;
      my $retval = $candidate->$method(@args);
      return $retval if defined $retval;
   }
   return;
}

sub load_user ($self, $id) { $self->_iterate(load_user => $id) }
sub load_user_by_name ($s, $n) { $s->_iterate(load_user_by_name => $n) }
sub save_user ($self, $user) { $self->_iterate(save_user => $user) }

1;
