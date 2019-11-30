#if defined(DM_PLATFORM_IOS)
#include <dmsdk/sdk.h>

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>

#include "gamecenter_utils.h"


static void PushError(lua_State* L, const char* error)
{
    // Could be extended with error codes etc
    if (error != 0) {
        lua_newtable(L);
        lua_pushstring(L, "error");
        lua_pushstring(L, error);
        lua_rawset(L, -3);
    } else {
        lua_pushnil(L);
    }
}

static void HandleRegistrationResult(const dmGameCenter::Command* cmd)
{
    lua_State* L = dmScript::GetCallbackLuaContext(cmd->m_Callback);
    DM_LUA_STACK_CHECK(L, 0);

    if (!dmScript::SetupCallback(cmd->m_Callback))
    {
        return;
    }
    
    if (cmd->m_playerID) {     
        dmLogInfo("login callback Result %s", cmd->m_playerID);
        lua_newtable(L);
        lua_pushstring(L, cmd->m_playerID);
        lua_setfield(L, -2, "playerID");
        if(cmd->m_alias){
            lua_pushstring(L, cmd->m_alias);
            lua_setfield(L, -2, "alias");
        }
        lua_pushnil(L);
    } else {
        lua_pushnil(L);
        PushError(L, cmd->m_Error);
        dmLogError("GCM error %s", cmd->m_Error);
    }

    int ret = dmScript::PCall(L, 3, 0);
    (void)ret;
    dmLogInfo("PCALL\n");
    dmScript::TeardownCallback(cmd->m_Callback);
    dmLogInfo("TeardownCallback\n");
}



void dmGameCenter::HandleCommand(dmGameCenter::Command* cmd, void* ctx)
{
    switch (cmd->m_Command)
    {
    case dmGameCenter::COMMAND_TYPE_REGISTRATION_RESULT:  HandleRegistrationResult(cmd); break;
    default: assert(false);
    }
    //free((void*)cmd->m_Error);
    //free((void*)cmd->m_playerID);
    //free((void*)cmd->m_alias);

    dmLogInfo("HandleCommand\n");
    //if (cmd->m_Command == dmGameCenter::COMMAND_TYPE_REGISTRATION_RESULT)
    //    dmScript::DestroyCallback(cmd->m_Callback);
}

void dmGameCenter::QueueCreate(CommandQueue* queue)
{
    queue->m_Mutex = dmMutex::New();
}

void dmGameCenter::QueueDestroy(CommandQueue* queue)
{
    {
        DM_MUTEX_SCOPED_LOCK(queue->m_Mutex);
        queue->m_Commands.SetSize(0);
    }
    dmMutex::Delete(queue->m_Mutex);
}

void dmGameCenter::QueuePush(CommandQueue* queue, Command* cmd)
{
    DM_MUTEX_SCOPED_LOCK(queue->m_Mutex);

    if(queue->m_Commands.Full())
    {
        queue->m_Commands.OffsetCapacity(2);
    }
    queue->m_Commands.Push(*cmd);
}

void dmGameCenter::QueueFlush(CommandQueue* queue, CommandFn fn, void* ctx)
{
    assert(fn != 0);
    if (queue->m_Commands.Empty())
    {
        return;
    }

    dmLogInfo("Game Center QueueFlush\n");
    DM_MUTEX_SCOPED_LOCK(queue->m_Mutex);
    for(uint32_t i = 0; i != queue->m_Commands.Size(); ++i){ fn(&queue->m_Commands[i], ctx); }
    //queue->m_Commands.Map(fn, ctx);
    queue->m_Commands.SetSize(0);
    dmLogInfo("Game Center QueueFlush End\n");
}

/** Gets a number (or a default value) as a integer from a table
*/
int checkTableNumber(lua_State* L, int index, const char* name, int default_value)
{
    DM_LUA_STACK_CHECK(L, 0);

    int result = -1;
    lua_pushstring(L, name);
    lua_gettable(L, index);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        return default_value;
    }
    else if (lua_isnumber(L, -1)) {
        result = lua_tointeger(L, -1);
    } else {
        return DM_LUA_ERROR("Wrong type for table attribute '%s'. Expected number, got %s", name, luaL_typename(L, -1));
    }
    lua_pop(L, 1);
    return result;
}

/** Gets a number (or a default value) as a double from a table
*/
double checkTableNumber(lua_State* L, int index, const char* name, double default_value)
{
    DM_LUA_STACK_CHECK(L, 0);

    double result = -1.0;
    lua_pushstring(L, name);
    lua_gettable(L, index);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        return default_value;
    }
    else if (lua_isnumber(L, -1)) {
        result = lua_tonumber(L, -1);
    } else {
        return DM_LUA_ERROR("Wrong type for table attribute '%s'. Expected number, got %s", name, luaL_typename(L, -1));
    }
    lua_pop(L, 1);
    return result;
}

/** Gets a string from a table
*/
const char* toTableString(lua_State* L, int index, const char* name)
{
    DM_LUA_STACK_CHECK(L, 0);

    lua_pushstring(L, name);
    lua_gettable(L, index);
    const char* result = lua_tostring(L, -1);
    lua_pop(L, 1);
    return result;
}

#endif // DM_PLATFORM_IOS
