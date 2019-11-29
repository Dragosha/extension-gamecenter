#if defined(DM_PLATFORM_IOS)
#ifndef DM_PUSH_UTILS
#define DM_PUSH_UTILS

#include <dmsdk/sdk.h>

namespace dmGameCenter
{

    enum LeaderboardTimeScope
    {
        LEADERBOARD_TIME_SCOPE_TODAY = 0,
        LEADERBOARD_TIME_SCOPE_WEEK = 1,
        LEADERBOARD_TIME_SCOPE_ALLTIME = 2,
    };

    enum LeaderboardPlayerScope
    {
        LEADERBOARD_PLAYER_SCOPE_GLOBAL = 0,
        LEADERBOARD_PLAYER_SCOPE_FRIENDS_ONLY =1,
    };

    enum CommandType
    {
        COMMAND_TYPE_REGISTRATION_RESULT  = 0,
    };

    struct Command
    {
        Command()
        {
            memset(this, 0, sizeof(Command));
        }
        dmScript::LuaCallbackInfo* m_Callback;

        uint32_t    m_Command;
        const char* m_Error;
        const char* m_playerID;
        const char* m_alias;
    };

    struct CommandQueue
    {
        dmArray<Command> m_Commands;
        dmMutex::HMutex  m_Mutex;
    };

    typedef void (*CommandFn)(Command* cmd, void* ctx);

    void QueueCreate(CommandQueue* queue);
    void QueueDestroy(CommandQueue* queue);
    void QueuePush(CommandQueue* queue, Command* cmd);
    void QueueFlush(CommandQueue* queue, CommandFn fn, void* ctx);

    void HandleCommand(dmGameCenter::Command* push, void* ctx);

}

int checkTableNumber(lua_State* L, int index, const char* name, int default_value);
const char* toTableString(lua_State* L, int index, const char* name);

#endif
#endif // DM_PLATFORM_IOS
