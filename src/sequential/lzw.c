#include "lzw.h"


/* -------- aux stuff ---------- */
//Pass in item_size in bytes and how many items to allocate on the heap
void* mem_alloc(size_t item_size, size_t n_item)
{
	size_t* x = calloc(1, sizeof(size_t) * 2 + n_item * item_size);
	x[0] = item_size; //in bytes
	x[1] = n_item;
	return x + 2; //return pointer starting at data
}

void* mem_extend(void* m, size_t new_n)
{
	size_t* x = (size_t*)m - 2; //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
	x = realloc(x, sizeof(size_t) * 2 + *x * new_n); //
	if (new_n > x[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
		memset((char*)(x + 2) + x[0] * x[1], 0, x[0] * (new_n - x[1]));
	x[1] = new_n;
	return x + 2;
}

void _clear(void* m)
{
	size_t* x = (size_t*)m - 2;
	memset(m, 0, x[0] * x[1]);
}

#define _new(type, n) mem_alloc(sizeof(type), n);
#define _del(m)   { free((size_t*)(m) - 2); m = 0; }
#define _len(m)   *((size_t*)m - 1)
#define _setsize(m, n)  m = mem_extend(m, n)
#define _extend(m)  m = mem_extend(m, _len(m) * 2)


/* ----------- LZW stuff -------------- */
typedef uint8_t byte;
typedef uint16_t ushort;

#define M_CLR 256 /* clear table marker */
#define M_EOD 257 /* end-of-data marker */
#define M_NEW 258 /* new code index */

typedef struct {
	ushort next[256];
} lzw_enc_t;

typedef struct {
	ushort prev, back;
	byte c;
} lzw_dec_t;

void write_bits(ushort x, uint32_t tmp, int bits, int out_len, int o_bits, byte* out) {
	tmp = (tmp << bits) | x;
	o_bits += bits;
	if (_len(out) <= out_len) _extend(out);
	while (o_bits >= 8) {
		o_bits -= 8;
		out[out_len++] = tmp >> o_bits;
		tmp &= (1 << o_bits) - 1;
	}
}

byte* lzw_encode(byte* in, int max_bits)
{
	int len = _len(in), bits = 9, next_shift = 512;
	ushort code, c, nc, next_code = M_NEW;
	lzw_enc_t* d = _new(lzw_enc_t, 512);

	if (max_bits > 15) max_bits = 15;
	if (max_bits < 9) max_bits = 12;

	byte* out = _new(ushort, 4);
	int out_len = 0, o_bits = 0;
	uint32_t tmp = 0;

	for (code = *(in++); --len; ) {
		c = *(in++);
		if ((nc = d[code].next[c])) 
			code = nc;
		else {
			tmp = (tmp << bits) | code; 
			o_bits += bits;
			if (_len(out) <= out_len) _extend(out); 
			while (o_bits >= 8) { 
				o_bits -= 8;
				out[out_len++] = tmp >> o_bits; 
				tmp &= (1 << o_bits) - 1;
			}
			nc = d[code].next[c] = next_code++;
			code = c;
		}

		if (next_code == next_shift) {
			if (++bits > max_bits) {
				tmp = (tmp << bits) | M_CLR;
				o_bits += bits;
				if (_len(out) <= out_len) _extend(out);
				while (o_bits >= 8) {
					o_bits -= 8;
					out[out_len++] = tmp >> o_bits;
					tmp &= (1 << o_bits) - 1;
				}

				bits = 9;
				next_shift = 512;
				next_code = M_NEW;
				_clear(d);
			}
			else
				_setsize(d, next_shift *= 2);
		}
	}

	tmp = (tmp << bits) | code;
	o_bits += bits;
	if (_len(out) <= out_len) _extend(out);
	while (o_bits >= 8) {
		o_bits -= 8;
		out[out_len++] = tmp >> o_bits;
		tmp &= (1 << o_bits) - 1;
	}
	tmp = (tmp << bits) | M_EOD;
	o_bits += bits;
	if (_len(out) <= out_len) _extend(out);
	while (o_bits >= 8) {
		o_bits -= 8;
		out[out_len++] = tmp >> o_bits;
		tmp &= (1 << o_bits) - 1;
	}
	if (tmp) {
		tmp = (tmp << bits) | tmp;
		o_bits += bits;
		if (_len(out) <= out_len) _extend(out);
		while (o_bits >= 8) {
			o_bits -= 8;
			out[out_len++] = tmp >> o_bits;
			tmp &= (1 << o_bits) - 1;
		}
	}

	_del(d);

	_setsize(out, out_len);
	return out;
}

byte* lzw_decode(byte* in)
{
	byte* out = _new(byte, 4);
	int out_len = 0;
	
	lzw_dec_t* d = _new(lzw_dec_t, 512);
	int len, j, next_shift = 512, bits = 9, n_bits = 0;
	ushort code, c, t, next_code = M_NEW;

	uint32_t tmp = 0;
	
	_clear(d);
	for (j = 0; j < 256; j++) d[j].c = j;
	next_code = M_NEW;
	next_shift = 512;
	bits = 9;

	for (len = (_len(in)); len;) {
		while (n_bits < bits) {
			if (len > 0) {
				len--;
				tmp = (tmp << 8) | *(in++);
				n_bits += 8;
			}
			else {
				tmp = tmp << (bits - n_bits);
				n_bits = bits;
			}
		}
		n_bits -= bits;
		code = tmp >> n_bits;
		tmp &= (1 << n_bits) - 1;
		if (code == M_EOD) break;
		if (code == M_CLR) {
			_clear(d);
			for (j = 0; j < 256; j++) d[j].c = j;
			next_code = M_NEW;
			next_shift = 512;
			bits = 9;
			continue;
		}

		if (code >= next_code) {
			fprintf(stderr, "Bad sequence\n");
			_del(out);
			goto bail;
		}

		d[next_code].prev = c = code;
		while (c > 255) {
			t = d[c].prev; d[t].back = c; c = t;
		}

		d[next_code - 1].c = c;

		while (d[c].back) {
			while (out_len >= _len(out)) _extend(out);
			out[out_len++] = d[c].c;
			t = d[c].back; d[c].back = 0; c = t;
		}
		while (out_len >= _len(out)) _extend(out);
		out[out_len++] = d[c].c;

		if (++next_code >= next_shift) {
			if (++bits > 16) {
				fprintf(stderr, "Too many bits\n");
				_del(out);
				goto bail;
			}
			_setsize(d, next_shift *= 2);
		}
	}

	if (code != M_EOD) fputs("Bits did not end in EOD\n", stderr);

	_setsize(out, out_len);
bail: _del(d);
	return out;
}

int lzw(char* input_file, char* out_file)
{
	int i, fd = open(input_file, O_RDONLY);

	if (fd == -1) {
		fprintf(stderr, "Can't read file\n");
		return 1;
	};
	
	struct stat st;
	fstat(fd, &st);

	byte* in = _new(unsigned char, st.st_size);
	read(fd, in, st.st_size);
	close(fd);

	byte* enc = lzw_encode(in, 9);
	FILE* encodedFile = fopen(out_file, "wb");
	fwrite(enc, _len(enc), 1, encodedFile);

	// byte* dec = lzw_decode(enc);
	// FILE* decodedFile = fopen("lzw_decoded.txt", "wb");
	// fwrite(dec, _len(dec), 1, decodedFile);
    
    // _del(dec);
	_del(in);
	_del(enc);
 

    return 0;
}