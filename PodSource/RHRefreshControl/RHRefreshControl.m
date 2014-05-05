//
//  RHRefreshControl.m
//  Example
//
//  Created by Ratha Hin on 2/1/14.
//  Copyright (c) 2014 Ratha Hin. All rights reserved.
//

#import "RHRefreshControl.h"
#import "RHRefreshControlConfiguration.h"

static void * KVOContext = &KVOContext;

@interface RHRefreshControl () <UIScrollViewDelegate>

@property (nonatomic, strong) UIView<RHRefreshControlView> *refreshView;
@property (nonatomic, assign) CGFloat minimumForStart;
@property (nonatomic, assign) CGFloat maximumForPull;

@property (nonatomic, assign) RHRefreshState state;

@property (nonatomic, strong) UIScrollView *scrollView;

@end

@implementation RHRefreshControl
{
    UIEdgeInsets _originalInsets;
    BOOL _ignoreInsetChanges;
    
    __weak id<UIScrollViewDelegate> _realDelegate;
}

- (id)initWithConfiguration:(RHRefreshControlConfiguration *)configuration {
    self = [super init];
    if (self) {
        _refreshView = configuration.refreshView;
        _minimumForStart = [configuration.minimumForStart floatValue];
        _maximumForPull = [configuration.maximumForPull floatValue];
    }
    
    return self;
}

- (void)attachToScrollView:(UIScrollView *)scrollView {
    _scrollView = scrollView;
    if ([scrollView isKindOfClass:[UITableView class]] && [(UITableView *)scrollView tableHeaderView]) {
        //[scrollView insertSubview:self.refreshView atIndex:1];
        [[(UITableView *)scrollView tableHeaderView] addSubview:self.refreshView];
    } else {
        [scrollView insertSubview:self.refreshView atIndex:0];
    }
    
    _originalInsets = scrollView.contentInset;
    [self positionRefreshView];
    
//    [scrollView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:KVOContext];

    [self setScrollViewDelegate:_scrollView.delegate];
    
    _attached = YES;
}

// save the reference to the real scrollview delegate but attach to scrollview ourself
- (void)setScrollViewDelegate:(id<UIScrollViewDelegate>)delegate
{
    _realDelegate = delegate;
    _scrollView.delegate = self;
    
}

- (void)dealloc
{
//    [_scrollView removeObserver:self forKeyPath:@"contentInset"];
    _scrollView.delegate = _realDelegate;
}

- (void)positionRefreshView
{
    if (_scrollView) {
        // if we haven't pulled enough to start pulling progress, then position it just above the content
        CGPoint startPosition = CGPointMake(CGRectGetMidX(_scrollView.bounds), -1*(self.minimumForStart) / 2);
        if (_scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart > 0) {
            self.refreshView.center = startPosition;
        } else {
            // now we're pulling, keep the refreshview sticking at the top
            startPosition.y += _scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart;
            self.refreshView.center = startPosition;
        }
    }
}
//
//- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
//{
//    // if it's this class instance that's doing the observation
//    if (context == KVOContext) {
//        DLog(@"scrolliew %@ inset changed:%@", object, change);
//        if ([keyPath isEqualToString:@"contentInset"]) {
//            // reposition the refresh view when view controller automatically sets insets for our scroll view
//            if (! _ignoreInsetChanges) {
//                _originalInsets = [[change objectForKey:@"new"] UIEdgeInsetsValue];
//                [self positionRefreshView];
//                _ignoreInsetChanges = YES;
//            }
//        }
//    }
//}

- (void)beginRefreshing
{
    if (self.state != RHRefreshStateLoading) {
        [self setState:RHRefreshStateLoading];
        [UIView animateWithDuration:0.3 animations:^{
            _scrollView.contentOffset = CGPointMake(_scrollView.contentOffset.x, - (_originalInsets.top + self.minimumForStart));
        }];
    }
}

- (void)endRefreshing {
    if (_scrollView && self.state != RHRefreshStateHidden) {
        
        DLog(@"ActuallyEndLoading - Set scrollview insets to %f", _originalInsets.top);
        
        
        // if user holded the scrollview for the whole time, we won't have the inset, so we reset it only if we do have it
        if (_scrollView.contentInset.top != _originalInsets.top) {
            [UIView animateWithDuration:0.2 animations:^{
                [_scrollView setContentInset:_originalInsets];
            }];
        }
        
        // if the scrollview is still pulled down then pull it up again
        if (_scrollView.contentOffset.y + _originalInsets.top < 0) {
            // kill the current drag gesture because we're forcing it to scroll up (and don't want it to jitter back)
            if (_scrollView.panGestureRecognizer.enabled) {
                _scrollView.panGestureRecognizer.enabled = NO;
                _scrollView.panGestureRecognizer.enabled = YES;
            }
            // scroll up
            [_scrollView setContentOffset:CGPointMake(_scrollView.contentOffset.x, -_originalInsets.top) animated:YES];
        }
        if ([self.refreshView respondsToSelector:@selector(updateViewOnComplete)]) {
            [self.refreshView updateViewOnComplete];
        }
        
        [self setState:RHRefreshStateHidden];
    } else {
        DLog(@"end loading called, but refresh control wasn't active");
    }
}


- (void)setState:(RHRefreshState)newState {
    
    switch (newState) {
        case RHRefreshStateNormal:
            [self.refreshView updateViewOnNormalStatePreviousState:_state];
            break;
            
        case RHRefreshStateLoading:
            [self.refreshView updateViewOnLoadingStatePreviousState:_state];
            
            if ([_delegate respondsToSelector:@selector(refreshDidTriggerRefresh:)]) {
                [_delegate refreshDidTriggerRefresh:self];
            }
            break;
            
        case RHRefreshStatePulling:
            [self.refreshView updateViewOnPullingStatePreviousState:_state];
            break;
            
        case RHRefreshStateHidden:
            [self.refreshView updateViewOnHiddenStatePreviousState:_state];
            break;
            
        default:
            break;
    }
    
    _state = newState;
    
}



#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [_realDelegate scrollViewDidScroll:scrollView];
    }
    
    // if we are just starting the movement
    if (self.state == RHRefreshStateHidden && _scrollView.dragging) {
        [self setState:RHRefreshStateNormal];
    }
    
    [self positionRefreshView];
    
    if (self.state != RHRefreshStateHidden) { // if it's hidden then user has released the scrollview and we're closing it, no point to update here
        // if we have pulled enough then start loading phase
        if (_scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart <= -self.maximumForPull) {
            // the state at this point can only be Normal or Pulling
            if (self.state != RHRefreshStateLoading) {
                [self setState:RHRefreshStateLoading];
            }
        } else if (_scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart < 0) { // if we have pulled more than a minimum
            if (self.state != RHRefreshStatePulling) {
                [self setState:RHRefreshStatePulling];
            }
            
            CGFloat deltaOffsetY = MIN(fabsf(_scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart), self.maximumForPull);
            CGFloat percentage = deltaOffsetY / self.maximumForPull;
            
            [self.refreshView updateViewWithPercentage:percentage state:self.state];
        } else {
            [self.refreshView updateViewWithPercentage:0 state:self.state];
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [_realDelegate scrollViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
        [_realDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [_realDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }

    if (self.state == RHRefreshStateLoading) {
        DLog(@"We ended dragging and it's loading state, so we add the inset");
        [UIView animateWithDuration:.1 animations:^{
            _scrollView.contentInset = UIEdgeInsetsMake(self.minimumForStart + _originalInsets.top, 0.0f, 0.0f, 0.0f);
        }];
    }
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(scrollViewShouldScrollToTop:)]) {
        return [_realDelegate scrollViewShouldScrollToTop:scrollView];
    } else {
        return YES; //it's default without the delegate
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(scrollViewDidScrollToTop:)]) {
        [_realDelegate scrollViewDidScrollToTop:scrollView];
    }
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) {
        [_realDelegate scrollViewWillBeginDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [_realDelegate scrollViewDidEndDecelerating:scrollView];
    }
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_realDelegate && [_realDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return [(id<UITableViewDelegate>)_realDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    } else {
        return 0;
    }
}


@end
