//
//  OSUTableView.m
//  BeaverTableView
//
//  Created by Chris Vanderschuere on 11/2/12.
//  Copyright (c) 2012 OSU iOS App Club. All rights reserved.
//

#import "OSUTableView.h"
#define PULL_HEIGHT self.rowHeight //This way the pull height can be changed as you change your row height

/* PRIVATE OSUTableView INTERFACE */
@interface OSUTableView()
 
    // Private Properties
    @property (nonatomic, strong) NSIndexPath *indexOfAddedCell;
    @property CGFloat addedRowHeight;   
    @property CGPoint upperPointOfPinch; // Used to store pinch from previous call of pinch handler

    // Private References Delegate & Datasource passed to us
    // We will use calls to this cachedDelegate/cachedDataSource combo rather than the UITableView delegate/dataSource throughout this class
    @property (nonatomic, assign) id <UITableViewDataSource> cachedDataSource;
    @property (nonatomic, assign) id <UITableViewDelegate> cachedDelegate;

    // Private Methods
    -(void) _customInit;
    -(void) _passSelector:(SEL)aSelector to:(id)aReciever;
    -(void) _commitDisgardCell;

@end // END PRIVATE OSUTableView INTERFACE


/* BEGIN OSUTableView Implementation */
@implementation OSUTableView


// Synthesize DataSource, Delegate and State
@synthesize cachedDataSource = _cachedDataSource, cachedDelegate = _cachedDelegate, state = _state;
// Synthesize Private Properties
@synthesize indexOfAddedCell = _indexOfAddedCell, addedRowHeight = _addedRowHeight, upperPointOfPinch = _upperPointOfPinch;


// The following two methods are what get written by @synthesize: We are overwritting the setter method so we can save a copy for internal use
// Overwriting setDelegate to save ViewController Delegate to cachedDelegate and set Self as New Delegate
-(void) setDelegate:(id<OSUTableViewDelegate>)delegate{
    //Get all delegate messages

    //We forward ones we don't implement with forwardInvocation
    self.cachedDelegate = delegate; //Save a reference for internal use..must set this first because the next line will trigger action
    
    [super setDelegate:self]; //Set delegate as you would would in UITableView
}


-(void) setDataSource:(id<OSUTableViewDataSource>)dataSource{
    // Currently Connect directly to Standard DataSource because we don't intercept anything yet
   
    self.cachedDataSource = dataSource; // Might as well store reference to this too for use in this class
    
    [super setDataSource:dataSource];   // Set DataSource as Standard DataSource for now
}



/* Scroll View Delegate (Calls Methods when Scrolling Events Happen) */
#pragma mark - UIScrollViewDelegate
//This works because uitableview inherits from uiscrollview
-(void) scrollViewDidScroll:(UIScrollView *)scrollView{    
    // Check if addingIndexPath doesn't exist and we are scrolling down from top
    if (scrollView.contentOffset.y<0 && self.indexOfAddedCell == nil && !scrollView.isDecelerating) {
        //Set state
        self.state = OSUTableViewStateDragging;
    
        //Add new cell to datasource
        [self beginUpdates];
        //Add a new object to our model
        [self.dataSource tableView:self commitEditingStyle:UITableViewCellEditingStyleInsert forRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        //Told table view to update at specific row
        [self insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        //Save indexpath and row height for later use
        self.indexOfAddedCell = [NSIndexPath indexPathForRow:0 inSection:0];
        self.addedRowHeight = fabsf(scrollView.contentOffset.y); //Floating absolute value
        
        [self endUpdates]; //All animations happen here
    }
    //Only do something here if DRAGGING
    else if (self.indexOfAddedCell && self.state == OSUTableViewStateDragging){
        // alter the contentOffset of our scrollView
        self.addedRowHeight += scrollView.contentOffset.y * -1;
        self.addedRowHeight = MAX(1,MIN(self.rowHeight, self.addedRowHeight)); //Make sure the row doesnt get bigger or smaller than it should 1<addedRowHeight<rowHeight
        [self reloadData];
    }
    //Pass method to delegate if necessary
    [self _passSelector:_cmd to:self.cachedDelegate];
}

//This is called when we lift our finger off the tableView
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    //Add cell if has been fully created
    [self _commitDisgardCell];
    
    //Change our state
    self.state = OSUTableViewStateNone;
    
    //Pass method to delegate if necessary
    [self _passSelector:_cmd to:self.cachedDelegate];
}

#pragma mark - UITableViewDelegate
-(CGFloat)tableView:(OSUTableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    //We need to use our custom height if this is the cell we are adding
    if ([indexPath isEqual:self.indexOfAddedCell]) {
        return self.addedRowHeight;
    }
    //Otherwise ask the delegate for a height to use. Optional method
    else if([self.cachedDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]){
        return [self.cachedDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    else
        return self.rowHeight; //Lastly use our rowHeight property; This is a default in UITableView
}

//This method disables the use of standard editing because we implement our own editing methods
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewCellAccessoryNone;
}

#pragma mark - UIGestureRecognizer Delegate Methods
//With this method we can stop gestures from functioning when they shouldn't


#pragma mark - UIGestureRecognizer Selectors
//This method will get called very frequently from beginnng..through changes...and after the gesture ends/cancels
-(void) handlePinch: (UIPinchGestureRecognizer *) pinchGesture{
    
    //Check if for failing condition(s)
    if(pinchGesture.state == UIGestureRecognizerStateEnded || pinchGesture.numberOfTouches < 2){
        //Commit/disgard cell if index has been added
        if(self.indexOfAddedCell){
            //Add/Disgard Cell
            [self _commitDisgardCell];
        }
        //Reset contentInset
        self.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        //Reset State
        self.state = OSUTableViewStateNone;
    }

    //Extract touch points from gesture relative to self
    CGPoint touch1 = [pinchGesture locationOfTouch:0 inView:self];
    CGPoint touch2 = [pinchGesture locationOfTouch:1 inView:self];
    
    //Determine Upper Point
    CGPoint upperPoint = touch1.y < touch2.y ? touch1 : touch2;
    CGPoint leftMostPoint = touch1.x < touch2.x ? touch1 : touch2;
    
    //Get Y Height
    CGFloat height = fabsf(touch1.y - touch2.y);
    //Determine change in height since last time
    
    CGFloat heightDelta = height - (height/(pinchGesture.scale)); //The change from the inital pinch pinch location; Pinch scale goes from 1 to larger as you pinch open->thus height delta goes from 0 to larger but at a faster rate
    
    //Switch on state of gesture recongnizer
    switch(pinchGesture.state){
        //Begin Pinch
        case UIGestureRecognizerStateBegan:{
            NSLog(@"Gesture Began");
            //Determine Index Path by making rect with points
            NSArray *indexPaths = [self indexPathsForRowsInRect:CGRectMake(leftMostPoint.x, upperPoint.y, fabsf(touch1.x - touch2.x), fabsf(touch1.y - touch2.y))];
            
            //Check if an index path exists in that rect
            if(indexPaths.count < 2){
                return;
            }
            
            //Set State
            self.state = OSUTableViewStatePinching;
            
            //Find the correct index between fingers and set to added index
            NSIndexPath *firstIndexPath = [indexPaths objectAtIndex:0];
            NSIndexPath *lastIndexPath = [indexPaths lastObject];
            
            NSInteger    midIndex = ((float)(firstIndexPath.row + lastIndexPath.row) / 2) + 0.5;
            
            NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:midIndex inSection:0];
            
            self.indexOfAddedCell = newIndexPath;
            
            //Save Reference to upper point
            self.upperPointOfPinch = upperPoint;
            
            //Add content inset to deal with scrolling issues..try without to show yourself
            self.contentInset = UIEdgeInsetsMake(self.bounds.size.height, 0, self.bounds.size.height, 0);
            
            //Start making updates
            [self beginUpdates];
            
            //Create new cell in data source 
            [self.cachedDataSource tableView:self commitEditingStyle:UITableViewCellEditingStyleInsert forRowAtIndexPath:self.indexOfAddedCell];
            
            //Insert new cell with animation
            [self insertRowsAtIndexPaths:[NSArray arrayWithObject:self.indexOfAddedCell] withRowAnimation:UITableViewRowAnimationNone];
            
            //End update...this is when this whole block executes
            [self endUpdates];

            break;
        }//Pinch Changed
        case UIGestureRecognizerStateChanged:{
            NSLog(@"GestureChanged");
            //If self.addedRowHeight - height delta is greater than 1...set height
            
            //MAX of heightdelta and 1
            self.addedRowHeight = MAX(1, heightDelta);
            
            //Reload data so new height gets added
            [self reloadData];
            
            // Scrolls tableview according to the upper touch point to mimic a realistic dragging gesture
            CGFloat diffOffsetY = self.upperPointOfPinch.y - upperPoint.y;
            self.contentOffset = CGPointMake(self.contentOffset.x,self.contentOffset.y+diffOffsetY);

            break;
        }
        case UIGestureRecognizerStateEnded:
            NSLog(@"Gesture Ended");
            break;
    }
            
}
    
#pragma mark - Utility
-(void) _commitDisgardCell{
    if ([self cellForRowAtIndexPath:self.indexOfAddedCell].bounds.size.height >= self.rowHeight) {
        //Keep cell but update cells
        [self beginUpdates];
        [self reloadRowsAtIndexPaths:[NSArray arrayWithObject:self.indexOfAddedCell] withRowAnimation:UITableViewRowAnimationNone];
        self.indexOfAddedCell = nil;
        self.addedRowHeight = 0;
        [self endUpdates];
    }
    else if(self.indexOfAddedCell){
        //Discard cell
        [self beginUpdates];
        //Delete from our model
        [self.dataSource tableView:self commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:self.indexOfAddedCell];
        //Remove from table view
        [self deleteRowsAtIndexPaths:[NSArray arrayWithObject:self.indexOfAddedCell] withRowAnimation:UITableViewRowAnimationNone];
        
        //No longer need to store added cell
        self.indexOfAddedCell = nil;
        self.addedRowHeight = 0;
        [self endUpdates]; //Animation happends here
    }
}


#pragma mark - Methods Forwarding
//These three methods are allow us to be our own delegate without taking away delegate calls for our cachedDelegate
-(BOOL)respondsToSelector:(SEL)aSelector{
    //This makes sure that all delegate methods are supported by the cachedDelegate are supported by us through message forwarding
    if ([super respondsToSelector:aSelector]) {
        return YES;
    }
    else{
        NSLog(@"Selector(%@): %@",self.cachedDelegate,NSStringFromSelector(aSelector));
        return [self.cachedDelegate respondsToSelector:aSelector];
    }
}

//This methods gets called any time this object recieves a message it doesn't have a corresponding method for
- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Forward: %@",NSStringFromSelector(anInvocation.selector));
    if ([self.cachedDelegate respondsToSelector:[anInvocation selector]])
        [anInvocation invokeWithTarget:self.cachedDelegate];
    else
        [super forwardInvocation:anInvocation];
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature* signature = [super methodSignatureForSelector:selector];
    if (!signature) {
        return [[self.cachedDelegate class] methodSignatureForSelector:selector];
    }
    return signature;
}

-(void) _passSelector:(SEL)aSelector to:(id)aReciever{
    if ([aReciever respondsToSelector:aSelector]) {
        //The following is to supress a warning you get by using performSelector: with ARC. Comment it out to try for yourself
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [aReciever performSelector:aSelector]; //Forward selector
        #pragma clang diagnostic pop 
    }
}

#pragma mark - Initilize Methods
//This is the init method that Interface Builder uses
-(id) initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder]; //Use UITableView Init methods
    if (self) {
        [self _customInit];
    }
    return self;
}

//This is the programatic init method
-(id) initWithFrame:(CGRect)frame style:(UITableViewStyle)style{
    self = [super initWithFrame:frame style:style]; //Use UITableView Init methods
    if (self) {
        [self _customInit];
    }
    return self;
}

//Now both paths for init will route through this methods...we will use it to add our custom gestures
-(void) _customInit{
    //Add Gesture Recognizers to current view
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    
    //Set self as delegate to recieve gesture calls
    pinch.delegate = self;
    
    [self addGestureRecognizer:pinch];
}

@end
