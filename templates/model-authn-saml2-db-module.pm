# SAML 2.0, cache module for keeping authentication data in a DB
package [% module %];
use Mojo::Base qw< [% all_modules.model_authn_saml2_module %] -signatures >;
use JSON::PP qw< encode_json decode_json >;

use constant DEFAULT_TABLE => 'logged_in';

has 'wmdb';
has table => sub { DEFAULT_TABLE };

sub get ($self, $key) {
   my $res = $self->wmdb->db->select($self->table, '*', { k => $key });
   return unless $res->size;
   my $record = $res->hash;
   return decode_json($record->{data}) if $record->{expire} > time();
   $self->wipe($key);
   return;
}

sub set ($self, $data, $key, $expire) {
   $self->wipe($key);
   $self->wmdb->db->insert($self->table,
      {
         k => $key,
         expire => $expire,
         data => encode_json($data)
      }
   );
   return $self;
}

sub wipe ($self, $key) {
   $self->wmdb->db->delete($self->table, { k => $key });
   return $self;
}

1;
