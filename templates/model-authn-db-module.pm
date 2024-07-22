package [% module %];
use Mojo::Base qw< [% all_modules.model_authn_local_module %] -signatures >;

has 'db';

sub load_user ($self, $id) {
   my $db = $self->db or return;
   return $db->select(account => '*', { id => $id })->hash;
}

sub load_user_by_name ($self, $name) {
   my $db = $self->db or return;
   return $db->select(account => '*', { name => $name })->hash;
}

sub save_user ($self, $user) {
   my $db = $self->db or return;
   $db->upsert(account => $user);
   return $self;
}

1;
