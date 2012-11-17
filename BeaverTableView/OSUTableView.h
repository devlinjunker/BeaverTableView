//
//  OSUTableView.h
//  BeaverTableView
//
//  Created by Chris Vanderschuere on 11/2/12.
//  Copyright (c) 2012 OSU iOS App Club. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef 
    enum OSUTableViewState {
        OSUTableViewStateNone = 0,
        OSUTableViewStateDragging = 1,
        OSUTableViewStatePinching = 2
    } 
OSUTableViewState;


// Create Our Own OSUTableViewDataSource Protocol Extending UITableViewDataSource Protocol
@protocol OSUTableViewDataSource <UITableViewDataSource>
    
    @required // Make the following required because we use it to add cells for gestures
    
    // commitEditingStyle Method to add Row to Data Source when we call it
    -(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath;

@end // End OSUTableViewDataSource Protocol


// Creating Our Own OSUTableViewDelegate Protocol (Gives us flexibility to add Methods to the UITableViewDelegate Protocol)
@protocol OSUTableViewDelegate <UITableViewDelegate>

@end // End OSUTableViewDelegate Protocol


// Creating Custom OSUTableView Interface, Extending the UITableView Interface 
//      Setting up to intercept dataSource Calls
//      We don't Implement Intercepting DataSource Calls at this Point (we do in .m file)
@interface OSUTableView : UITableView <UITableViewDelegate, UIGestureRecognizerDelegate> 

    // In our Custom OSUTableView we Override the standard delegate/datasource Protocols of UITableView to use our Custom Protocols
    @property (nonatomic, weak) IBOutlet id <OSUTableViewDataSource> dataSource;
    @property (nonatomic, weak) IBOutlet id <OSUTableViewDelegate> delegate;
    
    // Property for Enumed OSUTableViewState
    @property OSUTableViewState state;

@end
