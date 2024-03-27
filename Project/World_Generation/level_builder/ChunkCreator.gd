extends Node

signal done_instancing

const CHUNK_SIZE = 500

var chunks_loaded = 0

var chunks = 0## number of chunks to make
var chunk_map : Array = []

var chunk_template

## Multithreading vars
var mutex : Mutex
var t1 : Thread
var t2 : Thread
var t3 : Thread
var t4 : Thread

## Give info to begin loading on process
func begin_loading(chunk_temp, num_chunks):
	
	chunk_template = chunk_temp.instantiate()
	chunks = num_chunks
	
	## Prepare Empty Array
	chunk_map = [0]
	chunk_map.resize(chunks)
	for y in range(chunks):
		chunk_map[y] = [0]
		chunk_map[y].resize(chunks)
	
	## Create Chunks with multiple threads
	for x in range(chunks):
		for y in range(chunks):
			chunk_map[x][y] = _instance_chunk(chunk_template,x,y)
	
	## All done instancing chunks
	done_instancing.emit(chunk_map)
	
	

## begin Instancing Chunks each frame
func _instance_chunk(chunk_template,x,y):
	print("Instancing Chunk:"+str(x)+"_"+str(y))
	

