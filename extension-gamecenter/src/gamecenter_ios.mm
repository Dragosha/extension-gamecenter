#if defined(DM_PLATFORM_IOS)
#include "gamecenter_utils.h"

#include <dmsdk/sdk.h>
#include <vector>
#include <map>
#include <string>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>

#define LIB_NAME "GameCenter"
#define MODULE_NAME "gamecenter"

using namespace std;

struct GameCenter
{
    GameCenter()
    {
        memset(this, 0, sizeof(*this));
        m_ScheduledID = -1;
    }

    dmScript::LuaCallbackInfo*  m_Callback;
    dmScript::LuaCallbackInfo*  m_Listener;
    id<UIApplicationDelegate>   m_AppDelegate;
    dmGameCenter::CommandQueue  m_CommandQueue;
    int                         m_ScheduledID;
};

static GameCenter g_GameCenter;


@protocol GameCenterManagerDelegate <GKGameCenterControllerDelegate>
@end


NSString *const PresentAuthenticationViewController = @"present_authentication_view_controller";


@interface GameKitManager : UIViewController <GameCenterManagerDelegate>
{
@private UIViewController *m_authenticationViewController;
@private id<GameCenterManagerDelegate, NSObject> m_delegate;
}
+ (instancetype)sharedGameKitManager;
@end


@implementation GameKitManager

+ (instancetype)sharedGameKitManager
{
    static GameKitManager *sharedGameKitManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedGameKitManager = [[GameKitManager alloc] init];
    });
    return sharedGameKitManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        m_delegate = self;
    }
    return self;
}

- (void)authenticateLocalPlayer {
    NSLog (@"Authenticating local user...");
    @try {
        GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
        localPlayer.authenticateHandler  =
        ^(UIViewController *viewController, NSError *error) {


            if(viewController != nil) {
                NSLog (@"Game Center: User was not logged in. Show Login Screen.");
                [self setAuthenticationViewController:viewController];
            } else if([GKLocalPlayer localPlayer].isAuthenticated) {
                NSLog (@"Game Center: You are logged in to game center.");
                // NSString *playerID=localPlayer.playerID;
                // NSString *alias=localPlayer.alias;

                dmGameCenter::Command cmd;
                cmd.m_Callback = g_GameCenter.m_Callback;
                cmd.m_Command = dmGameCenter::COMMAND_TYPE_REGISTRATION_RESULT;
                cmd.m_playerID = [localPlayer.playerID UTF8String];
                cmd.m_alias = [localPlayer.alias UTF8String];
                dmGameCenter::QueuePush(&g_GameCenter.m_CommandQueue, &cmd);

            } else if (error != nil) {
                NSLog (@"Game Center: Error occurred authenticating-");
                NSLog (@"  %@", [error localizedDescription]);

                dmGameCenter::Command cmd;
                cmd.m_Callback = g_GameCenter.m_Callback;
                cmd.m_Command = dmGameCenter::COMMAND_TYPE_REGISTRATION_RESULT;
                cmd.m_Error = [[error localizedDescription] UTF8String];
                dmGameCenter::QueuePush(&g_GameCenter.m_CommandQueue, &cmd);
            } else {
                dmGameCenter::Command cmd;
                cmd.m_Callback = g_GameCenter.m_Callback;
                cmd.m_Command = dmGameCenter::COMMAND_TYPE_REGISTRATION_RESULT;
                cmd.m_Error = "Unknown";
                dmGameCenter::QueuePush(&g_GameCenter.m_CommandQueue, &cmd);
            }
        };
    }
    @catch (NSException *exception){
        NSLog(@"authenticateLocalPlayer Caught an exception");
    }
    @finally{
        NSLog(@"authenticateLocalPlayer Cleaning up");
    }
}


- (void)setAuthenticationViewController:(UIViewController *)authenticationViewController  {
    @try {
        m_authenticationViewController = authenticationViewController;
        [[NSNotificationCenter defaultCenter]
        postNotificationName:PresentAuthenticationViewController
        object:self];
    }
    @catch (NSException *exception){
        NSLog(@"setAuthenticationViewController Caught an exception");
    }
}


- (bool) isGameCenterAvailable {
    return true;
}

- (void) login {
    @try {

             NSLog(@"login in GameCenter is available");
            [[NSNotificationCenter defaultCenter]
             addObserver:self
             selector:@selector(showAuthenticationViewController)
             name:PresentAuthenticationViewController
             object:nil];

            [self authenticateLocalPlayer];
    }
    @catch (NSException *exception){
        NSLog(@"login Caught an exception");
    }
}

- (void) reportScore:(NSString*)leaderboardId score:(int)score
{
    GKScore* scoreReporter = [[GKScore alloc] initWithLeaderboardIdentifier:leaderboardId];
    scoreReporter.value = (int64_t)score;
    [GKScore reportScores:@[scoreReporter] withCompletionHandler:^(NSError *error) {;}];
}

- (void)submitAchievement:(NSString*)identifier withPercentComplete:(double)percentComplete
{
    GKAchievement *achievement = [[[GKAchievement alloc] initWithIdentifier:identifier]  autorelease];
    [achievement setPercentComplete:percentComplete];
    achievement.showsCompletionBanner = YES;
    [achievement reportAchievementWithCompletionHandler:^(NSError  *error) {
        if (error)
        {
            //cbk->m_Error = new GKError([error code], [[error localizedDescription] UTF8String]);
        }
    }];
}


// BEGIN SHOW THE STANDARD USER INTERFACE
- (void)showAuthenticationViewController
{
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:m_authenticationViewController
                                                                                 animated:YES
                                                                               completion:nil];
}

- (void)showLeaderboards:(NSString*)leaderboardId withTimeScope:(int)timeScope {
    [self showLeaderboard:leaderboardId withTimeScope:timeScope];
}

- (void)showLeaderboards:(int)timeScope {
    [self showLeaderboard:nil withTimeScope:timeScope];
}

- (void)showLeaderboard:(NSString*)leaderboardId withTimeScope:(int)timeScope {
    GKGameCenterViewController* gameCenterController = [[GKGameCenterViewController alloc] init];
    gameCenterController.viewState = GKGameCenterViewControllerStateLeaderboards;
    gameCenterController.leaderboardTimeScope = (GKLeaderboardTimeScope)timeScope;
    if(leaderboardId != nil) {
        gameCenterController.leaderboardIdentifier = leaderboardId;
    }
    gameCenterController.gameCenterDelegate = self;

    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:
     gameCenterController animated:YES completion:nil];
}

- (void)showAchievements {
    GKGameCenterViewController* gameCenterController = [[GKGameCenterViewController alloc] init];
    gameCenterController.viewState = GKGameCenterViewControllerStateAchievements;
    gameCenterController.gameCenterDelegate = self;

    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:
     gameCenterController animated:YES completion:nil];
}
// END SHOW THE STANDARD USER INTERFACE


// BEGIN DELEGATE
- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController*) gameCenterViewController {
    [[UIApplication sharedApplication].keyWindow.rootViewController dismissViewControllerAnimated:true completion:nil];
}

//END DELEGATE

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


////////////////
// API

static int isAvailable(lua_State* L)
{
    bool status=true;
    lua_pushboolean(L, status);
    return 1;
}


/** Authenticate local player, show Game Center login modal if not logged yet.
 */
static int login(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);

    if (g_GameCenter.m_Callback)
        dmScript::DestroyCallback(g_GameCenter.m_Callback);

    g_GameCenter.m_Callback = dmScript::CreateCallback(L, 1);

    [[GameKitManager sharedGameKitManager] login];
    return 0;
}


/** Submit a score for a specified Leader Board
 */
static int reportScore(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    int n = lua_gettop(L);
    const char *leaderboardId = 0;
    int score = 0;

    if(n > 2) {
        leaderboardId = lua_tostring(L, 1);
        score = lua_tonumber(L, 2);
    } else {
        leaderboardId = toTableString(L, 1, "leaderboardId");
        score = checkTableNumber(L, 1, "score", 0);
    }

    dmLogInfo("leaderboardId : %s\n", leaderboardId);
    dmLogInfo("score : %d\n", score);


    [[GameKitManager sharedGameKitManager] reportScore:@(leaderboardId) score:score];
    return 0;
}

static int showLeaderboards(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    int n = lua_gettop(L);

    const char *leaderboardId = 0;
    int timeScope = dmGameCenter::LEADERBOARD_TIME_SCOPE_ALLTIME;

    if(n == 0) {
        [[GameKitManager sharedGameKitManager] showLeaderboards:timeScope];
    }else if(lua_isnumber(L, 1)) {
        timeScope = lua_tointeger(L, 1);
        [[GameKitManager sharedGameKitManager] showLeaderboards:timeScope];
    }else if(lua_istable(L, 1)) {
        leaderboardId = toTableString(L, 1, "leaderboardId");
        timeScope = checkTableNumber(L, 2, "timeScope", dmGameCenter::LEADERBOARD_TIME_SCOPE_ALLTIME);
        [[GameKitManager sharedGameKitManager] showLeaderboards:@(leaderboardId) withTimeScope:timeScope];
    }else {
        leaderboardId = lua_tostring(L, 1);
        timeScope = lua_tointeger(L, 2);
        [[GameKitManager sharedGameKitManager] showLeaderboards:@(leaderboardId) withTimeScope:timeScope];
    }
    return 0;
}


static int showAchievements(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    [[GameKitManager sharedGameKitManager] showAchievements];
    return 0;
}

/** Submit Achievement
 */
static int submitAchievement(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);

    const char *identifier = 0;
    double percentComplete = 0.0;
    int n = lua_gettop(L);

    if(n > 2) {
        identifier = lua_tostring(L, 1);
        percentComplete = lua_tonumber(L, 2);
    }else {
        identifier = toTableString(L, 1, "identifier");
        percentComplete = checkTableNumber(L, 1, "percentComplete", 0.0);
    }

    [[GameKitManager sharedGameKitManager] submitAchievement:@(identifier) withPercentComplete:percentComplete];
    return 0;
}


static const luaL_reg Module_methods[] =
{
    //
    {"login", login},
    {"isAvailable",isAvailable}, // fake
    {"reportScore", reportScore},
    {"showLeaderboards", showLeaderboards},
    {"showAchievements", showAchievements},
    {"submitAchievement", submitAchievement},
    //{"loadAchievements", loadAchievements},
    //{"resetAchievements", resetAchievements},

    {0, 0}
};


static dmExtension::Result AppInitializeGameCenter(dmExtension::AppParams* params)
{
    dmGameCenter::QueueCreate(&g_GameCenter.m_CommandQueue);
    return dmExtension::RESULT_OK;
}

static dmExtension::Result UpdateGameCenter(dmExtension::Params* params)
{
    dmGameCenter::QueueFlush(&g_GameCenter.m_CommandQueue, dmGameCenter::HandleCommand, 0);
    return dmExtension::RESULT_OK;
}

static dmExtension::Result AppFinalizeGameCenter(dmExtension::AppParams* params)
{
    dmGameCenter::QueueDestroy(&g_GameCenter.m_CommandQueue);
    return dmExtension::RESULT_OK;
}

static dmExtension::Result InitializeGameCenter(dmExtension::Params* params)
{
    lua_State*L = params->m_L;
    int top = lua_gettop(L);
    luaL_register(L, MODULE_NAME, Module_methods);

#define SETCONSTANT(name, val) \
        lua_pushnumber(L, (lua_Number) val); \
        lua_setfield(L, -2, #name);\


    SETCONSTANT(LEADERBOARD_PLAYER_SCOPE_GLOBAL, dmGameCenter::LEADERBOARD_PLAYER_SCOPE_GLOBAL);
    SETCONSTANT(LEADERBOARD_PLAYER_SCOPE_FRIENDS_ONLY, dmGameCenter::LEADERBOARD_PLAYER_SCOPE_FRIENDS_ONLY);

    SETCONSTANT(LEADERBOARD_TIME_SCOPE_TODAY, dmGameCenter::LEADERBOARD_TIME_SCOPE_TODAY);
    SETCONSTANT(LEADERBOARD_TIME_SCOPE_WEEK, dmGameCenter::LEADERBOARD_TIME_SCOPE_WEEK);
    SETCONSTANT(LEADERBOARD_TIME_SCOPE_ALLTIME, dmGameCenter::LEADERBOARD_TIME_SCOPE_ALLTIME);

#undef SETCONSTANT

    lua_pop(L, 1);
    assert(top == lua_gettop(L));

    dmLogInfo("Registered %s Lua extension\n", MODULE_NAME);
    return dmExtension::RESULT_OK;
}

static dmExtension::Result FinalizeGameCenter(dmExtension::Params* params)
{
    if (g_GameCenter.m_Listener)
        dmScript::DestroyCallback(g_GameCenter.m_Listener);
    if (g_GameCenter.m_Callback)
        dmScript::DestroyCallback(g_GameCenter.m_Callback);
    g_GameCenter.m_Listener = 0;
    g_GameCenter.m_Callback = 0;
    return dmExtension::RESULT_OK;
}

DM_DECLARE_EXTENSION(GameCenterExtExternal, "GameCenter", AppInitializeGameCenter, AppFinalizeGameCenter, InitializeGameCenter, UpdateGameCenter, 0, FinalizeGameCenter)
#endif // DM_PLATFORM_IOS
