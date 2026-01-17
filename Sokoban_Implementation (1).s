#ENHANCEMENTS:
#Implemented multiple boxes and targets:
#	How: stored all the co-ordinates of the boxes in a heap. Same with
#	co-ordinates of the targets in another heap. Each byte corresponds
#	to an x or y co-ordinate. X co-ordinates are on the even offsets of
#	the heaps, while Y are on the odd. 
#	Implemented the storing by simply assigning the heap and using a while
#	loop to assign until the iterator reached box_count (LINE 137)
#	Implemented the moving my iterating through the entire heap to see
#	if a move matched where the character was moving, and changed the
#	x or y value in the heap respectively, then jumped to create_gameboard
#	since it was modified.(LINE 726- how move_up is implemented using the heap)
#	Implemented the checking win by iterating through the board state
#	in heap.




.data
seed:       .word 0x12345678
gridsize:   .byte 8,8 # width and length of the Sokoban board
character:  .byte 0,0
box:        .byte 0,0
target:     .byte 0,0
box_count:  .byte 1
# The maximum number of squares is 255 * 255 = 65 025. thus, box_count
# cannot exceed that (it is less than a halfword)
#  since there must be space for targets too!
# Therefore, it seems better to keep the box_count as a byte size, 
# although it may be limiting significantly.
character_symbol: .String "@"
box_symbol:       .String "H"
target_symbol:    .String "X"
top_wall:         .String "_"
bottom_wall:      .String "-"
side_wall:        .String "#"
empty:            .String "."
newline:          .String "\n"
WINNER:           .String "   ***   \n ( ^_^ ) \n  / ~ \\  \n /_____\\"
prompt_box_count: .String "Would you like to change the number of boxes and targets (y/n)?\n"
prompt_number:    .String "\nPlease state how many boxes you would like:\n"
Invalid:          .String "\nPlease enter a valid answer\n"

.text
.globl _start

_start:
	li sp, 0x80000000
	# let seed be a random number (time)
	la t1, seed
	li a7, 30            # Syscall number for time
    ecall                # Get current time
    sw a0, 0(t1)          # Store current time as seed
	
	la a0, prompt_box_count
	li a7, 4
	ecall
	
	li a7, 12
	ecall
	
	li t0, 'y'
	beq a0, t0, change_box_count
	
	li t0, 'n'
	beq a0, t0, set_default_count
	
	la a0, Invalid
	li a7, 4
	ecall
	j _start
	
	change_box_count:
	la a0, prompt_number
	li a7, 4
	ecall
	
	li a7, 5
	ecall
	mv t2, a0
	
	la a1, box_count
	sb t2, 0(a1)
	j begin
	
set_default_count:
	li a0, 1
	la a1, box_count
	sb a0, 0(a1)
    # TODO: Generate locations for the character, box, and target. Static
    # locations in memory have been provided for the (x, y) coordinates 
    # of each of these elements.
begin:
	
	la t0, gridsize
	lb s0, 0(t0) # grid width DO NOT override s0
	lb s1, 1(t0) #grid length DO NOT overrise s1
	
	addi s3, s0, 3
	addi s4, s1, 2
	mul s4, s3, s4
	
	#Allocate the memory to the heap
	li a7, 9
	mv a0, s4
	ecall
	mv s3, a0  # s3 holds pointer for heap (currently empty)
	
	li a7, 9
	mv a0, s4
	ecall
	mv s4, a0  #s4 holds the pointer for a backup of the board
	# base address of heap & backup held in a separate registers:
	mv s5, s3
	mv s6, s4
	# 1. store character location
character_location_store:
	# X of character
	mv a0, s0   # Get a random number from [0, grid[x]) x coordinate
	jal notrand
	mv t3, a0
	
	#Y of character
	mv a0, s1  #random y coordinate 
	jal notrand
	mv t4, a0
	
    la a0, character
	# store character (X,Y)
	sb t3, 0(a0)
	sb t4, 1(a0)  # increment address by 1 since data size is byte
	
	#2. store box location
la a0, box_count
lb a0, 0(a0)
slli a0, a0, 1  #Each box has two single byte co-ordinates
li a7, 9
ecall
mv s2, a0      #Number of boxes allocated on heap. s2 is heap starter
mv s8, s2      #s8 is back-up

la a0, box_count
lb a0, 0(a0)
slli a0, a0, 1  #Each box has two single byte co-ordinates
li a7, 9
ecall
mv s7, a0      #Number of targets allocated on heap. s7 is heap starter
mv s9, s7	   # s9 is back-up

li s10, 0      #Counter for storing the boxes & targets
WHILE:
	la a0, box_count
	lb a0, 0(a0)
	beq s10, a0, print
box_location_find:
	# X of box
	mv a0, s0   # Get a random number from [0, grid[x]) x coordinate
	jal notrand
	mv t3, a0
	
	# Y of box
	mv a0, s1  #random y coordinate
	jal notrand
	mv t4, a0
	
	# compare with character co-ordinates
	# a0 = &character
	la a0, character
	
# if both x and y of box are same as character, relocate box
	#FOR CHARACTER
	checkX_box_overlap:
		# if X == character[x], checkY_box
		lb t1, 0(a0)
		beq t3, t1, checkY_box_overlap
		
	Box_corner_test:
		#elif x == 0, check if Y == 0, or Y == grid[y] - 1
		beqz t3, Box_corner_check

		#elif x == grid[x] - 1, check if Y == 0 or Y == grid[y] - 1
		addi t1, s0, -1
		beq t3, t1, Box_corner_check
		
		#elif 
		
		#Else store location if no chance of overlap or corner
		
		j box_location_store
	# FOR CHARACTER
	checkY_box_overlap:
		# if X == character[x] then come to checkY_box:
		# if Y == character[y] then overlap confirmed, go to box_location_find
		lb t1, 1(a0)
		beq t4, t1, box_location_find
		
		# if not overlapped, could still be in corner, so check that
		j Box_corner_test
		
	
	Box_corner_check:
		# now we know X == 0 or X == grid[x] - 1,
		# check if Y == 0 or Y == grid[y] - 1
		
		# Y == 0? then box is at (0, 0) or (grid[x] - 1, 0)!
		beqz t4, box_location_find
		# Y == grid[y] - 1? then box is at (0, grid[y] - 1) 
		# or (grid[x] - 1,grid[y] - 1)!
		
		addi t1, s1, -1
		beq t4, t1, box_location_find
		
		# if in neither corner or overlap, go to store.
		j box_location_store
		
		additional_checks_box:
		# t3 is random box x, t4 is random box y
		# need to check that it is placed on a "." character on heap
		# We know that heap is already initialized since this label is
		# jumped to when there is more than one box. 
		# formula for index of heap. Index = (y + 1)(board[x] + 3) + (x + 2)
		# 1. Check that the place of the box is empty (not overlapping with anything)
		addi t1, s0, 3
		addi t2, t4, 1
		mul t1, t2, t1  # t1 = (y + 1)(board[x] + 3)
		
		addi t2, t3, 1  # t2 = (x + 1)
		add t1, t1, t2  # t1 is index of s3 needed
		
		mv s3, s5
		add s3, s3, t1
		lb t2, 0(s3)   # using base address of s3, which is in s5
		
		li a1, '.'
		
		beq a1, t2, no_overlap
		# there is another character in its place, find another location
		j box_location_find
		
		no_overlap:
		#ensured that there is no overlap, now check surrounding for solvability
		#1. need to make sure that only one side has no "." The rest should!
		li a1, 0 # counter for number of "." surrounding box
		
		addi t1, t1, -1
		mv s3, s5
		add s3, s3, t1
		lb t2, 0(s3)  # right before the box
		
		li a2, '.'
		beq a2, t2, increment
		li a2, 'X'
		beq a2, t2, increment
		li a2, '@'
		beq a2, t2, increment
		
		right_empty:
		addi t1, t1, 2 
		mv s3, s5
		add s3, s3, t1
		lb t2, 0(s3)  # right after the box
		li a2, '.'
		beq a2, t2, increment_right
		li a2, 'X'
		beq a2, t2, increment_right
		li a2, '@'
		beq a2, t2, increment_right
		
		up_empty:
		addi t1, t1, -1
		addi t2, s0, 3
		sub t1, t1, t2 # right above the box
		mv s3, s5
		add s3, s3, t1
		lb t2, 0(s3)
		li a2, '.'
		beq a2, t2, increment_up
		li a2, 'X'
		beq a2, t2, increment_up
		li a2, '@'
		beq a2, t2, increment_up
		
		down_empty:
		addi t2, s0, 3
		add t1, t2, t1
		add t1, t2, t1 # right below box (2 down from right above)
		mv s3, s5
		add s3, s3, t1
		lb t2, 0(s3)
		li a2, '.'
		beq a2, t2, increment_down
		li a2, 'X'
		beq a2, t2, increment_down
		li a2, '@'
		beq a2, t2, increment_down
		
		final_surrounding:
		li a0, 3
		blt a1, a0, box_location_find
		
		j store
		
		increment:
		addi a1, a1, 1
		j right_empty
		
		increment_right:
		addi a1, a1, 1
		j up_empty
		
		increment_up:
		addi a1, a1, 1
		j down_empty
		
		increment_down:
		addi a1, a1, 1
		j final_surrounding
		
	
# if box does not overlap target or in corner, store location
box_location_store:
	li a0, 0
	bne s10, a0, additional_checks_box
	store:
	la a0, box
	sb t3, 0(a0)
	sb t4, 1(a0)
	
	sb t3, 0(s2)
	sb t4, 1(s2)
	addi s2, s2, 2
	
	
	#3. store target location
	# Main edge case: check if grid has width or height that is 1. If true
	# then target must be after box. aka, can't be| 0 X H | since character 
	# cannot push!
	# other edge case, if box is on edge, target must be on same edge
	# edge when: x = 0, x = grid[x] - 1, y = 0, or y = grid[y] - 1 of box
	beqz t3, target_on_edge_X
	addi t1, s0, -1
	beq t3, t1, target_on_edge_X
	
	beqz t4, target_on_edge_Y
	addi t1, s1, -1
	beq t4, t1, target_on_edge_Y
	
	# ELSE (box not on edges):
target_location_find:
	mv a0, s0   # Get a random number from [0, 8) x coordinate
	jal notrand
	mv t3, a0
	
	mv a0, s1  #random y coordinate
	jal notrand
	mv t4, a0
	
	# Make sure there is no overlap
	
	# check for box and target overlap
	la a0, box
	lb t1, 0(a0)
	beq t3, t1, checkY_target_overlap_box
	
	#check for character and target overlap
	overlap_check_character:
	la a1, character
	lb t1, 0(a1)
	beq t3, t1, checkY_target_overlap_character
	
	j target_location_store
	
	checkY_target_overlap_box:
	la a0, box
	lb t1, 1(a0)
	beq t4, t1, target_location_find
	
	j overlap_check_character
	
	checkY_target_overlap_character:
	la a1, character
	lb t1, 1(a1)
	beq t4, t1, target_location_find
	
	j target_location_store
	
	
target_on_edge_X:
	# since box is on an X edge (on either left or right), target on same edge
	# t3 is box location right now, so only randomize t4
	mv a0, s1
	jal notrand
	mv t4, a0
	
	addi t1, s0, 3
	addi t2, t4, 1
	mul t1, t2, t1  # t1 = (y + 1)(board[x] + 3) TESTING t4, -> Y

	addi t2, t3, 1  # t2 = (x + 1) 
	add t1, t1, t2  # t1 is index of s3 needed

	mv s3, s5
	add s3, s3, t1
	lb t2, 0(s3)   # using base address of s3, which is in s5

	li a1, '.'

	bne a1, t2, target_on_edge_X # find another t4
	
	la a0, box
	lb a0, 1(a0)
	beq t4, a0, target_on_edge_X
	
	j store_t
	
target_on_edge_Y:
	# t4 stays the same!
	mv a0, s0
	jal notrand
	mv t3, a0  #test out this t3
	
	addi t1, s0, 3
	addi t2, t4, 1
	mul t1, t2, t1  # t1 = (y + 1)(board[x] + 3)

	addi t2, t3, 1  # t2 = (x + 1)  TESTING t3
	add t1, t1, t2  # t1 is index of s3 needed

	mv s3, s5
	add s3, s3, t1
	lb t2, 0(s3)   # using base address of s3, which is in s5

	li a1, '.'

	bne a1, t2, target_on_edge_Y # find another t3
	la a0, box
	lb a0, 0(a0)
	beq t3, a0, target_on_edge_Y
	
	j store_t
	
additional_checks_target:
		# t3 is random target x, t4 is random target y
		# need to check that it is placed on a "." character on heap
		# We know that heap is already initialized since this label is
		# jumped to when there is more than one target. 
		# formula for index of heap. Index = (y + 1)(board[x] + 3) + (x + 2)
		# 1. Check that the place of the target is empty (not overlapping with anything)
		addi t1, s0, 3
		addi t2, t4, 1
		mul t1, t2, t1  # t1 = (y + 1)(board[x] + 3)
		
		addi t2, t3, 1  # t2 = (x + 1)
		add t1, t1, t2  # t1 is index of s3 needed
		
		mv s3, s5
		add s3, s3, t1
		lb t2, 0(s3)   # using base address of s3, which is in s5
		
		li a1, '.'
		
		bne a1, t2, target_location_find
		# there is another character in its place, find another location
		j store_t
		
target_location_store:
	li a0, 0
	bne s10, a0, additional_checks_target
	store_t:
	la a0, target
	sb t3, 0(a0)
	sb t4, 1(a0)
	
	sb t3, 0(s7)
	sb t4, 1(s7)
	addi s7, s7, 2

	addi s10, s10, 1  #pair of box and target stored!
	
    # There is a notrand function that you can use to start with. It's 
    # really not very good; you will replace it with your own rand function
    # later. Regardless of the source of your "random" locations, make 
    # sure that none of the items are on top of each other and that the 
    # board is solvable.
   
    # TODO: Now, print the gameboard. Select symbols to represent the walls,
    # character, box, and target. Write a function that uses the location of
    # the various elements (in memory) to construct a gameboard and that 
    # prints that board one character at a time.
    # HINT: You may wish to construct the string that represents the board
    # and then print that string with a single syscall. If you do this, 
    # consider whether you want to place this string in static memory or 
    # on the stack. 
# Initializes and update the gameboard!
create_gameboard:
	# reset s3 to the start of the heap	
	mv s3, s5
	
	la a0, character
	lb t0, 0(a0)
	lb t1, 1(a0)
	
	la a0, box_count
	lb a0, 0(a0)
	slli a0, a0, 1
	
	addi sp, sp, -8
	sw s2, 0(sp)
	sw s7, 4(sp)
	
	mv s2, s8  # s2 points to start of box heap
	lb t2, 0(s2)	# t2 is the x position of first box
	
	mv s7, s9  # s7 points to start of target heap
	lb t3, 0(s7)    # t3 is the x position of first target
	
	la t4, box_count
	mv t4, s10    # store the box count somewhere
	
	li t5, 0        # number of boxes stored currently
	
	li t6, -1  # X index (column)
	li a3, -1  # Y index (row)
	li a4, 0  # number of targets stored currently
	
	print_loop:
	addi a5, s1, 1
	beq a3, a5, end_board  # go to the final print
	li t6, -1
	
		print_row:
		addi a5, s0, 1
		beq t6, a5, new_line #add newline to stack if finished row

		#skipping first and last row
		#check if current position is character, box, or target
		li a5, -1
		beq a3, a5, store_top_wall

		addi a7, s1, 0
		beq a3, s1, store_bottom_wall

		li a5, -1
		beq t6, a5, store_side_wall
		addi a7, s0, 0
		beq t6, s0, store_side_wall

		blt a3, s1, check_inner_grid

		j store_empty

		check_inner_grid:
			mv s2, s8
			mv s7, s9
			beq a3, t1, check_character

			box_test:
			mv a0, s8
			add a0, a0, s10
			add a0, a0, s10
			bge s2, a0, target_test
			
			beq t4, t5, target_test
			lb t2, 0(s2)
			beq t6, t2, check_box
			
			addi s2, s2, 2
			j box_test
			
			target_test:
			mv a0, s9
			add a0, a0, s10
			add a0, a0, s10
			bge s7, a0, store_empty  #if none of targets at current spot
			
			beq t4, a4, store_empty  # if all targets are stored
			lb t3, 0(s7)
			beq t6, t3, check_target
			
			addi s7, s7, 2   #Check next target's X
			j target_test

		store_empty:
			la a0, empty
			j push_symbol

		check_character:
			beq t6, t0, store_character
			j box_test

		check_box:
			addi s2, s2, 1  # Y of the box in heap
			lb t2, 0(s2)
			beq a3, t2, store_box
			addi s2, s2, 1 #Go to next target's X
			
			j box_test
		check_target:
			addi s7, s7, 1  # Y of target in heap
			lb t3, 0(s7)
			beq a3, t3, store_target
			addi s7, s7, 1
			
			j target_test

		store_character:
			la a0, character_symbol
			j push_symbol

		store_box:
			addi t5, t5, 1  # increment the stored boxes counter
			addi s2, s2, 1 # Go to the next X of box (check if it even exists)
			la a0, box_symbol
			j push_symbol

		store_target:
			addi a4, a4, 1  # increment the stored targets counter
			addi s7, s7, 1  # Go to the next X of target to be checked.
			la a0, target_symbol
			j push_symbol

		store_top_wall:
			la a0, top_wall
			j push_symbol
		store_bottom_wall:
			la a0, bottom_wall
			j push_symbol
		store_side_wall:
			la a0, side_wall
			j push_symbol

		push_symbol:
			lb a0, 0(a0)
			sb a0, 0(s3)
			
			addi s3, s3, 1 # next byte of heap to store IN

			addi t6, t6, 1  # column + 1
			j print_row
	new_line:
		li a0, 0x0a
		sb a0, 0(s3)
		addi s3, s3, 1  # go to next byte of heap
		
		addi a3, a3, 1  #row + 1
		j print_loop
		
end_board:
	sb x0, 0(s3)  # null pointer for the end of the stack

	mv s3, s5
	lw s2, 0(sp)
	lw s7, 4(sp)
	addi sp, sp, 8
	
	j WHILE
	
print:
	mv a0, s3
	li a7, 4
	ecall	

    # TODO: Enter a loop and wait for user input. Whenever user input is
    # received, update the gameboard state with the new location of the 
    # player (and if applicable, box and target). Print a message if the 
    # input received is invalid or if it results in no change to the game 
    # state. Otherwise, print the updated game state. 
gameloop:
	mv s2, s8  #reset heap of boxes to start
	mv s7, s9  #reset heap of target to start
	
	# ---CHECK WINNER---
	mv s3, s5  #start of heap in s3
	
	addi t0, s0, 3
	addi t1, s1, 2
	mul t0, t0, t1 #Size of the heap in t0
	
	li t1, 0  #Counter
	LOOP_WINNER:
		beq t1, t0, declare_winner
		lb t2, 0(s3)
		li t3, 'X'
		beq t2, t3, continue
		addi t1, t1, 1
		addi s3, s3, 1
		j LOOP_WINNER
	declare_winner:
		la a0, WINNER
		li a7, 4
		ecall
		j exit
	
	continue:
	li a7, 12
	ecall
	mv a6, a0  #the user input game
	
	la a0, character
	lb t1, 0(a0)  #X co-ordinate of player, Column
	lb t2, 1(a0)  #Y co-ordinate of player, Row

	
	li a0, 'w'
	beq a6, a0, move_up
	li a0, 's'
	beq a6, a0, move_down
	li a0, 'a'
	beq a6, a0, move_left
	li a0, 'd'
	beq a6, a0, move_right
	li a0, 'r'
	beq a6, a0, start_ops
	
	li a0, 'e'
	beq a6, a0, exit
	
	j invalid_input
	
	start_ops:
	li s3, 0
	li s4, 0
	li s6, 0
	li s2, 0
	li s5, 0
	li s7, 0
	li s8, 0
	li s9, 0
	j 0x0
# ---MOVE UP----
	move_up:

	beqz t2, gameloop
	
	
	addi t2, t2, -1
	
	#Iterate through all the boxes to see if
	#any box needs to be moved
		move_box_up_loop:
			lb t3, 0(s2)
			lb t4, 1(s2)
			beq t3, t1, check_box_up
			addi s2, s2, 2
			
			mv a0, s8
			add a0, a0, s10
			add a0, a0, s10
			bge s2, a0, up_Else #If no box matches, finish moving player
			j move_box_up_loop
			
		check_box_up:
		beq t2, t4, move_box_up
		addi s2, s2, 2
		
		mv a0, s8
		add a0, a0, s10
		add a0, a0, s10
		bge s2, a0, up_Else
		
		j move_box_up_loop
		
		up_Else:
		la a0, character
		sb t2, 1(a0)
		j create_gameboard

		move_box_up:
		beqz t4, gameloop
		
		
		mv a0, s5
		addi a1, t1, 0
		addi a2, t2, -1
		jal find_character
		
		mv t0, a0
		li a0, 'H'
		beq t0, a0, gameloop
		
		
		la a0, character
		sb t2, 1(a0)
		
		addi t2, t2, -1
		sb t2, 1(s2)
		j create_gameboard
		
# ---MOVE DOWN---
	move_down:
	#1. If at bottom already, don't move
	la a0, gridsize
	lb a0, 1(a0)
	addi a0, a0, -1
	beq t2, a0, gameloop

	#add one for the place below
	addi t2, t2, 1
	
		move_box_down_loop:
			lb t3, 0(s2)
			lb t4, 1(s2)
			beq t3, t1, check_box_down
			addi s2, s2, 2
			
			mv a0, s8
			add a0, a0, s10
			add a0, a0, s10
			bge s2, a0, down_Else #If no box matches, finish moving player
			j move_box_down_loop
			
		check_box_down:
		beq t2, t4, move_box_down
		addi s2, s2, 2
		mv a0, s8
		add a0, a0, s10
		add a0, a0, s10
		bge s2, a0, down_Else
		j move_box_down_loop
		
		down_Else:
		la a0, character
		sb t2, 1(a0)
		j create_gameboard
		
		move_box_down:
		
		la a0, gridsize
		lb a0, 1(a0)
		addi a0, a0, -1
		beq t4, a0, gameloop
		
		mv a0, s5
		addi a1, t1, 0
		addi a2, t2, 1
		jal find_character
		
		mv t0, a0
		li a0, 'H'
		beq t0, a0, gameloop
		
		
		la a0, character
		sb t2, 1(a0)
		
		addi t2, t2, 1
		sb t2, 1(s2)
		j create_gameboard

	
	move_left:
	beqz t1, gameloop
	
	
	addi t1, t1, -1
	
		move_box_left_loop:
			lb t3, 0(s2)
			lb t4, 1(s2)
			beq t3, t1, check_box_left
			addi s2, s2, 2
			
			mv a0, s8
			add a0, a0, s10
			add a0, a0, s10
			bge s2, a0, left_Else #If no box matches, finish moving player
			j move_box_left_loop
			
		check_box_left:
		beq t2, t4, move_box_left
		addi s2, s2, 2
		mv a0, s8
		add a0, a0, s10
		add a0, a0, s10
		bge s2, a0, left_Else #If no box matches, finish moving player
		j move_box_left_loop
		
		left_Else:
		la a0, character
		sb t1, 0(a0)
		j create_gameboard

		move_box_left:
		
		beqz t3, gameloop
		
		mv a0, s5
		addi a1, t1, -1
		addi a2, t2, 0
		jal find_character
		
		mv t0, a0
		li a0, 'H'
		beq t0, a0, gameloop
		
		
		la a0, character
		sb t1, 0(a0)
		
		addi t1, t1, -1
		sb t1, 0(s2)
		j create_gameboard
	
	move_right:

	la a0, gridsize
	lb a0, 0(a0)
	addi a0, a0, -1
	beq t1, a0, gameloop


	addi t1, t1, 1

		move_box_right_loop:
			lb t3, 0(s2)
			lb t4, 1(s2)
			beq t3, t1, check_box_right
			addi s2, s2, 2
			
			mv a0, s8
			add a0, a0, s10
			add a0, a0, s10
			bge s2, a0, right_Else #If no box matches, finish moving player
			j move_box_right_loop
		
		check_box_right:
		beq t2, t4, move_box_right
		
		addi s2, s2, 2
		mv a0, s8
		add a0, a0, s10
		add a0, a0, s10
		bge s2, a0, right_Else #If no box matches, finish moving player
		j move_box_right_loop
		
		right_Else:
		la a0, character
		sb t1, 0(a0)
		j create_gameboard
		
		move_box_right:
		
		la a0, gridsize
		lb a0, 0(a0)
		addi a0, a0, -1
		beq t3, a0, gameloop
		
		mv a0, s5
		addi a1, t1, 1
		addi a2, t2, 0
		jal find_character
		
		mv t0, a0
		li a0, 'H'
		beq t0, a0, gameloop
		
		
		la a0, character
		sb t1, 0(a0)
		
		addi t1, t1, 1
		sb t1, 0(s2)
		j create_gameboard

	
	
	invalid_input:
	j gameloop
	
    #
    # You will also need to restart the game if the user requests it and 
    # indicate when the box is located in the same position as the target.
    # For the former, it may be useful for this loop to exist in a function,
    # to make it cleaner to exit the game loop.

    # TODO: That's the base game! Now, pick a pair of enhancements and
    # consider how to implement them.
	
exit:
	
    li a7, 10
    ecall
    
    
# --- HELPER FUNCTIONS ---
# Feel free to use, modify, or add to them however you see fit.
#PSUEDORANDOM GENERATOR: XOR Shift. 
#Reference: Marsaglia, George (July 2003). "Xorshift RNGs".
#		Journal of Statistical Software. 8 (14).
#		DOI:https://doi.org/10.18637/jss.v008.i14

# Arguments: an integer MAX in a0
# Return: A number from 0 (inclusive) to MAX (exclusive)
notrand:

	addi sp, sp, -16      # Move stack pointer down to make space
    sw ra, 0(sp)
	sw t1, 4(sp)
	sw t2, 8(sp)
	sw t3, 12(sp)

	
	la t1, seed

	lw t2, 0(t1)
	
	# x ^= x << 13
	slli t3, t2, 13
	xor t2, t2, t3
	
	# x^= x >> 17
	srli t3, t2, 17
	xor t2, t2, t3
	
	# x^= x << 5
	slli t3, t2, 5
	xor t2, t2, t3
	
	
	sw t2, 0(t1)
		
	
	remu a0, t2, a0
	
	lw ra, 0(sp) # Load the return address back into ra
	lw t1, 4(sp)
	lw t2, 8(sp)
	lw t3, 12(sp)
	
    addi sp, sp, 16
	
	
	jr ra
	
# Arguments: start of gameboard heap in a0, and 
#a1, a2 as the co-ordinates of where to find it
#Return: returns the character stored in heap at specified co-ordinates, in a0
find_character:
	addi sp, sp, -8
	sw t5, 0(sp)
	sw t6, 4(sp)
	
	addi t5, s0, 3
	addi t6, a2, 1
	
	mul t5, t5, t6
	
	addi t6, a1, 1
	add t5, t5, t6
	
	add a0, a0, t5
	lb a0, 0(a0)
	
	lw t5, 0(sp)
	lw t6, 4(sp)
	addi sp, sp, 8
	
	jr ra
