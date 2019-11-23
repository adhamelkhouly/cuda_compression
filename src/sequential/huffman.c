// #include <stdio.h>
// #include <stdlib.h>
// #include <string.h>
#include <stdint.h>
#include <inttypes.h>

#include "huffman.h"

// #include "../file_manipulation.h"

typedef struct node_t {
	struct node_t *left, *right;
	int freq;
	char c;
} *node;

struct node_t pool[256] = {{0}};
node qqq[255], *q = qqq - 1;
int n_nodes = 0, qend = 1;
char *code[128] = {0}, buf[1024];

node new_node(int freq, char c, node a, node b)
{
	node n = pool + n_nodes++;
	if (freq) n->c = c, n->freq = freq;
	else {
		n->left = a, n->right = b;
		n->freq = a->freq + b->freq;
	}
	return n;
}

/* priority queue */
void qinsert(node n)
{
	int j, i = qend++;
	while ((j = i / 2)) {
		if (q[j]->freq <= n->freq) break;
		q[i] = q[j], i = j;
	}
	q[i] = n;
}

node qremove()
{
	int i, l;
	node n = q[i = 1];

	if (qend < 2) return 0;
	qend--;
	while ((l = i * 2) < qend) {
		if (l + 1 < qend && q[l + 1]->freq < q[l]->freq) l++;
		q[i] = q[l], i = l;
	}
	q[i] = q[qend];
	return n;
}

/* walk the tree and put 0s and 1s */
void build_code(node n, char *s, int len)
{
	static char *out = buf;
	if (n->c) {
		s[len] = 0;
		strcpy(out, s);
		code[n->c] = out;
		out += len + 1;
		return;
	}

	s[len] = '0'; build_code(n->left,  s, len + 1);
	s[len] = '1'; build_code(n->right, s, len + 1);
}

void init(const char *s)
{
	int i, freq[128] = {0};
	char c[16];

	while (*s) freq[(int)*s++]++;

	for (i = 0; i < 128; i++)
		if (freq[i]) qinsert(new_node(freq[i], i, 0, 0));

	while (qend > 2)
		qinsert(new_node(0, 0, qremove(), qremove()));

	build_code(q[1], c, 0);
}

void encode(const char *s, char *out)
{
	while (*s) {
		strcpy(out, code[*s]);
		out += strlen(code[*s++]);
	}
}

void decode(const char *s, node t)
{
	node n = t;
	while (*s) {
		if (*s++ == '0') n = n->left;
		else n = n->right;

		if (n->c) putchar(n->c), n = t;
	}

	putchar('\n');
	if (t != n) printf("garbage input\n");
}

uint8_t* huffman(char* input_str) {
	int len = strlen(input_str);
	long maxSize = len*len;
	printf("maxSize = %ld\n", maxSize);
	char* dest = (char*)malloc(maxSize * sizeof(char));
	for(int i = 0; i < maxSize; i++) {
		dest[i] = '\0';
	}
	// char dest[maxSize] = {0};
	init(input_str);

	encode(input_str, dest);
	// int i;
	// for(i = 0; i < maxSize; i++) {
	// 	if(dest[i] == '\0') break;
	// }
	printf("size = %ld bits\n", strlen(dest));
	printf("size = %ld bytes\n", strlen(dest)/8);

	uint8_t *reps = (char*)malloc(strlen(dest) * sizeof(char));
	int idx = 0;
	for(int i = 0; i < strlen(dest); i += 8) {
		char tmp[8];
		memcpy(tmp, (dest + i), 8*sizeof(char));
		uint8_t rep = (uint8_t)strtol(tmp, NULL, 2);

		reps[idx] = rep;
		idx++;
	}
	printf("idx = %d\n", idx);
	return reps;
}

// int main(void)
// {
// 	char * str = read_file("alice29.txt");
// 	int len = strlen(str);
// 	// char buf[1024*1024];
// 	char* buf = (char*)malloc(sizeof(char) * (len * len + 1));

// 	init(str);
// 	for (int i = 0; i < 128; i++)
// 		if (code[i]) printf("'%c': %s\n", i, code[i]);

// 	encode(str, buf);
// 	printf("encoded: %s\n", buf);

// 	// printf("decoded: ");
// 	// decode(buf, q[1]);

// 	return 0;
// }
