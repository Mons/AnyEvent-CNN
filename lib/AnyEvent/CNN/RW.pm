package AnyEvent::CNN::RW;

use parent 'AnyEvent::CNN';
use AnyEvent::RW;
use Event::Emitter;

sub _on_connected_prepare {
	my ($self,$fh,$host,$port) = @_;
	warn "success: @_";
	$self->{h} = AnyEvent::RW->new(
		fh => $self->{fh},
		#timeout => $self->{timeout},
		on_read => $self->{on_read} || sub {
			$self->event(on_read => @_);
		},
		on_end => sub {
			$self->disconnect(@_ ? @_ : "$!");
			$self->_reconnect_after;
		}
	);
}

1;