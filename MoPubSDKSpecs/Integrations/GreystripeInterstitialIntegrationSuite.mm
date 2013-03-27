#import "MPInterstitialAdController.h"
#import "MPAdConfigurationFactory.h"
#import "FakeGSFullScreenAd.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(GreystripeInterstitialIntegrationSuite)

describe(@"GreystripeInterstitialIntegrationSuite", ^{
    __block id<MPInterstitialAdControllerDelegate, CedarDouble> delegate;
    __block MPInterstitialAdController *interstitial = nil;
    __block UIViewController *presentingController;
    __block FakeGSFullscreenAd *greystripeAd;
    __block FakeMPAdServerCommunicator *communicator;
    __block MPAdConfiguration *configuration;

    beforeEach(^{
        // Because MPInterstitialAdController has a shared pool, we need to clear it before each run.
        [MPInterstitialAdController removeSharedInterstitialAdController:interstitial];

        delegate = nice_fake_for(@protocol(MPInterstitialAdControllerDelegate));

        interstitial = [MPInterstitialAdController interstitialAdControllerForAdUnitId:@"greystripe_interstitial"];
        interstitial.delegate = delegate;

        presentingController = [[[UIViewController alloc] init] autorelease];

        // request an Ad
        [interstitial loadAd];
        communicator = fakeProvider.lastFakeMPAdServerCommunicator;
        communicator.loadedURL.absoluteString should contain(@"greystripe_interstitial");

        // prepare the fake and tell the injector about it
        greystripeAd = [[[FakeGSFullscreenAd alloc] init] autorelease];
        fakeProvider.fakeGSFullscreenAd = greystripeAd;

        // receive the configuration -- this will create an adapter which will use our fake interstitial
        configuration = [MPAdConfigurationFactory defaultInterstitialConfigurationWithCustomEventClassName:@"GreystripeInterstitialCustomEvent"];
        [communicator receiveConfiguration:configuration];

        // clear out the communicator so we can make future assertions about it
        [communicator reset];

        setUpInterstitialSharedContext(communicator, delegate, interstitial, @"greystripe_interstitial", greystripeAd, configuration.failoverURL);
    });

    context(@"while the ad is loading", ^{
        it(@"should configure Greystripe properly and start fetching the interstitial", ^{
            greystripeAd.GUID should equal(@"YOUR_GREYSTRIPE_GUID");
            greystripeAd.didFetch should equal(YES);
        });

        it(@"should not tell the delegate anything, nor should it be ready", ^{
            delegate.sent_messages should be_empty;
            interstitial.ready should equal(NO);
        });

        context(@"and the user tries to load again", ^{ itShouldBehaveLike(anInterstitialThatPreventsLoading); });
        context(@"and the user tries to show the ad", ^{ itShouldBehaveLike(anInterstitialThatPreventsShowing); });
    });

    context(@"when the ad successfully loads", ^{
        beforeEach(^{
            [delegate reset_sent_messages];
            [greystripeAd simulateLoadingAd];
        });

        it(@"should tell the delegate and -ready should return YES", ^{
            verify_fake_received_selectors(delegate, @[@"interstitialDidLoadAd:"]);
            interstitial.ready should equal(YES);
        });

        context(@"and the user tries to load again", ^{ itShouldBehaveLike(anInterstitialThatHasAlreadyLoaded); });

        context(@"and the user shows the ad", ^{
            beforeEach(^{
                greystripeAd.isAdReady = YES;
                [delegate reset_sent_messages];
                fakeProvider.lastFakeMPAnalyticsTracker.trackedImpressionConfigurations.count should equal(0);
                [interstitial showFromViewController:presentingController];
            });

            it(@"should track an impression and tell the custom event to show", ^{
                verify_fake_received_selectors(delegate, @[@"interstitialWillAppear:", @"interstitialDidAppear:"]);
                greystripeAd.presentingViewController should equal(presentingController);
                fakeProvider.lastFakeMPAnalyticsTracker.trackedImpressionConfigurations.count should equal(1);
            });

            context(@"when the user interacts with the ad", ^{
                beforeEach(^{
                    [delegate reset_sent_messages];
                });

                it(@"should track only one click, no matter how many interactions there are, and shouldn't tell the delegate anything", ^{
                    [greystripeAd simulateUserTap];
                    fakeProvider.lastFakeMPAnalyticsTracker.trackedClickConfigurations.count should equal(1);

                    [greystripeAd simulateUserTap];
                    fakeProvider.lastFakeMPAnalyticsTracker.trackedClickConfigurations.count should equal(1);

                    delegate.sent_messages.count should equal(0);
                });
            });

            context(@"and the user tries to load again", ^{ itShouldBehaveLike(anInterstitialThatHasAlreadyLoaded); });

            context(@"when the ad is dismissed", ^{
                beforeEach(^{
                    [delegate reset_sent_messages];
                    [greystripeAd simulateUserDismissingAd];
                    verify_fake_received_selectors(delegate, @[@"interstitialWillDisappear:"]);
                    [greystripeAd simulateInterstitialFinishedDisappearing];
                    verify_fake_received_selectors(delegate, @[@"interstitialDidDisappear:"]);
                });

                it(@"should tell the delegate and should no longer be ready", ^{
                    interstitial.ready should equal(NO);
                });

                context(@"and the user tries to load again", ^{ itShouldBehaveLike(anInterstitialThatStartsLoadingAnAdUnit); });
                context(@"and the user tries to show the ad", ^{ itShouldBehaveLike(anInterstitialThatPreventsShowing); });
            });
        });

        context(@"GREYSTRIPE SAD PATH: when the interstitial uncaches *before* it is shown", ^{
            beforeEach(^{
                [delegate reset_sent_messages];
                greystripeAd.isAdReady = NO;
                [interstitial showFromViewController:presentingController];
            });

            it(@"should not track any impressions", ^{
                fakeProvider.lastFakeMPAnalyticsTracker.trackedImpressionConfigurations should be_empty;
            });

            it(@"should not tell Greystripe to show", ^{
                greystripeAd.presentingViewController should be_nil;
            });

            itShouldBehaveLike(anInterstitialThatLoadsTheFailoverURL);
        });
    });

    context(@"when the ad fails to load", ^{
        beforeEach(^{
            [delegate reset_sent_messages];
            [greystripeAd simulateFailingToLoad];
        });

        itShouldBehaveLike(anInterstitialThatLoadsTheFailoverURL);
    });
});

SPEC_END
