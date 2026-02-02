Game design

Things we need to build

Pieces. if we are going to have battles we need troops.

a piece is going to need the following

```Python
@dataclass
def piece:
	id:int # maybe a uuid
	size:int # how many are inside
	health:int # our hit points
	sight:int # how many hexregion they can go 
	memory:float # how much they forget
	thoughts: #see below
	range:int # how many weighted hexpositions can they go
	goal:enum # explore, harvest,attack, move, settle
	targetHex:hexpostion # where they want to go relative to them. can be none
	target: #uuid a player piece they want to go after:
	personality: #if left on their own are what are their tendenceis towards doing a goal
	spans:pieces that you created
	path: a shape of the item like SVGDef pattern. It takes Flag colour scheme.
```
functions/methods that we will need.
```
def encode

def decode

def merge:
	pieces can merge into other pieces to make larger pieces" the intial piece is destroyed
	
def knoweledge:
	pieces know around them based upon their sight. they can be passed a certain number of hexes from their parent to know about and they will forget a certain number based upon their memory to pass to their descendents. and also forget a cerain amount they send to their bosses.

def harvest:
	if a piece has settled (which will take a certian number of turns) it can harvest an area which will cause it to create new pieces at a rate based upon the terrain and the size of the item.
	
def move:
	go to a hex.
	
det attack:
	we need some combat system to figure out who wins between items.
	
def plan:
uses knowlege to figure out what to do next
```

we need to figure out how to move and see, some thoughts
1. we have uphill and down hill.
2. things like forrest and jungles can be harder to see  and move through
3. we should have routes between parents and their children. but these routes can only be a certain size based upon distance. movement should be increased.

## Storeage and Turns

right now we have  things stored at the game board level. we need to add a turn field to it. Then the question is do we store all of the pieces there. I am tempted to store them all in a separate table and track their moves there. The issue is with the web is that we need to go back and forth on each indivual move for a turn and the terrain will only change at most at the end of a turn (if new countries are created). 

## Interface 

we will need to have various routes for our web sever. I am thinking about 5 panels
1. left side top - a menu system (we would have file (load,duplicate,new) countires something that would navigate). we should also let it you toggle between unmoved pieces and potentially list them (so we could have sub menus)
2. left  side bottom - a detail sceen base upon side top. so clicking on a country would have the country detials, a piece the piece details
3. the map
4. below the map things that we might want to toggle - are we showing routes or climates flos, watershed etx
5. right side a debug info. Maybe some sort of log console

we will need to build out these overlays.
	
	