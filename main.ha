use fmt;

type Pair = struct {
    head: *Object,
    tail: *Object,
};

type Object = struct {
    marked: bool,
    next: nullable *Object,
    value: (Pair | int),
};

type VM = struct {
    stack: [256]nullable *Object,
    stack_size: int,
    first_object: nullable *Object,
    num_objects: int,
    max_objects: int,
};

fn newVM () *VM = {
	return alloc(VM {
		stack = [null...],
		stack_size = 0,
		first_object = null,
		num_objects = 0,
		max_objects = 8,
	});
};

fn push(vm: *VM, value: *Object) void = {
    assert(vm.stack_size < 8, "Stack overflow");
    vm.stack[vm.stack_size] = value;
    vm.stack_size += 1;
};

fn pop(vm: *VM) *Object = {
    assert(vm.stack_size > 0, "Stack underflow");
    const return_obj = vm.stack[vm.stack_size - 1] as *Object;
    vm.stack_size -= 1;
    return return_obj;
};

fn mark(object: *Object) void = {
    if(object.marked)
    	return;
    object.marked = true;
    if(object.value is Pair) {
    	let pair = object.value as Pair;
    	mark(pair.head);
    	mark(pair.tail);
	};
};

fn markall(vm: *VM) void = {
	for(let i=0; i<vm.stack_size; i+=1) {
		let elem = vm.stack[i] as *Object;
		mark(elem);
	};
};

fn sweep(vm: *VM) void = {
	let object: *nullable *Object = &vm.first_object;
	for(!(*object is null)) {
		let obj = *object as *Object;
		if(!(obj.marked)) {
			let unreached = obj;
			*object = unreached.next;
			free(unreached);
			vm.num_objects -= 1;
		} else {
			obj.marked = false;
			object = &(obj.next);
		};
	};
};

fn gc(vm: *VM) void = {
	let num_objects = vm.num_objects;
	markall(vm);
	sweep(vm);
	if(vm.num_objects == 0)
		vm.max_objects = 8
	else
		vm.max_objects = vm.num_objects * 2;
	fmt::printfln("Collected {} objects, {} remaining.", num_objects -
		vm.num_objects, vm.num_objects)!;
};

fn new_object(vm: *VM, value: (int | Pair)) *Object = {
	if(vm.num_objects == vm.max_objects)
		gc(vm);
	vm.num_objects += 1;
	let object = alloc(Object {
		marked = false,
		next = vm.first_object,
		value = value
	});
	vm.first_object = object;
	return object;
};

fn push_int(vm: *VM, value: int) void = {
	let obj = new_object(vm, value);
	push(vm,obj);
};

fn push_pair(vm: *VM) *Object = {
	let x = pop(vm);
	let y = pop(vm);
	let pair: Pair = struct {
		head: *Object = x,
		tail: *Object = y
	};
	let obj = new_object(vm,pair);
	push(vm,obj);
	return obj;
};

fn print(object: *Object) void = {
	match(object.value) {
	case let i: int =>
		fmt::println(i)!;
	case let p: Pair =>
		fmt::print("(")!;
		print(p.head);
		fmt::print(",")!;
		print(p.tail);
		fmt::print(")\n")!;
	};
};

fn freeVM (vm: *VM) void = {
	vm.stack_size = 0;
	gc(vm);
	free(vm);
};

fn test1() void = {
  fmt::println("Test 1: Objects on stack are preserved.")!;
  let vm = newVM();
  push_int(vm, 1);
  push_int(vm, 2);

  gc(vm);
  assert(vm.num_objects == 2, "Should have preserved objects.");
  freeVM(vm);
};

fn test2() void = {
  fmt::println("Test 2: Unreached objects are collected")!;
  let vm = newVM();
  push_int(vm, 1);
  push_int(vm, 2);
  pop(vm);
  pop(vm);

  gc(vm);
  assert(vm.num_objects == 0, "Should have collected objects.");
  freeVM(vm);
};

fn test3() void = {
  fmt::println("Test 3: Reach nested objects")!;
  let vm = newVM();
  push_int(vm, 1);
  push_int(vm, 2);
  push_pair(vm);
  push_int(vm, 3);
  push_int(vm, 4);
  push_pair(vm);
  push_pair(vm);

  gc(vm);
  assert(vm.num_objects == 7, "Should have reached nested objects.");
  freeVM(vm);
};

fn test4() void = {
  fmt::println("Test 4: Handle cycles.")!;
  let vm = newVM();
  push_int(vm, 1);
  push_int(vm, 2);
  let a = push_pair(vm);
  push_int(vm, 3);
  push_int(vm, 4);
  let b = push_pair(vm);

  // Set up a cycle, and also make 2 and 4 unreachable and collectible. */
  (a.value as Pair).tail = b;
  (b.value as Pair).tail = a;

  gc(vm);
  assert(vm.num_objects == 4, "Should have collected objects.");
  freeVM(vm);
};


export fn main() void = {
	test1();
	test2();
	test3();
	test4();
};
