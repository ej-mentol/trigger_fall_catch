const int SF_FC_START_OFF = 1;
const int SF_FC_KILL = 2;
const int SF_FC_KEEP_ANGLES = 4;
const int SF_FC_KEEP_VELOCITY = 8;
const int SF_FC_REF_TARGET = 16;
const int SF_FC_DEBUG = 32;

const SOUND_CHANNEL FC_SOUND_CHANNEL = CHAN_AUTO;
const string FC_SOUND_FILE = "debris/alien_teleport.wav";
const float FC_THINK_INTERVAL = 0.1f;
const float FC_DEST_LIFT = 16.0f;
const float FC_DEBUG_INTERVAL = 5.0f;

class CFallCatch : ScriptBaseEntity
{
	float m_flOffset = -8.0f;
	float m_flRadius = 0.0f;
	float m_flCooldownTime = 0.5f;
	array<float> m_flPlayerNext( 33, 0.0f );
	string m_szFire;
	string m_szDest;
	string m_szWatch;
	float m_flNextDebug = 0.0f;
	bool m_bEnabled = true;
	bool m_bDebug = false;

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if ( szKey == "offset" )
		{
			m_flOffset = atof( szValue );
			return true;
		}
		else if ( szKey == "radius" )
		{
			m_flRadius = atof( szValue );
			return true;
		}
		else if ( szKey == "teleport_cooldown" )
		{
			m_flCooldownTime = atof( szValue );
			return true;
		}
		else if ( szKey == "fire_target" )
		{
			m_szFire = szValue;
			return true;
		}
		else if ( szKey == "dest_target1" )
		{
			m_szDest = szValue;
			return true;
		}
		else if ( szKey == "watch" )
		{
			m_szWatch = szValue;
			return true;
		}
		return BaseClass.KeyValue( szKey, szValue );
	}

	void Spawn()
	{
		pev.solid = SOLID_NOT;
		pev.effects = EF_NODRAW;

		m_bEnabled = ( pev.spawnflags & SF_FC_START_OFF ) == 0;
		m_bDebug = ( pev.spawnflags & SF_FC_DEBUG ) != 0;

		SetThink( ThinkFunction( this.Think ) );
		SetUse( UseFunction( this.Use ) );
		pev.nextthink = g_Engine.time + FC_THINK_INTERVAL;

		if ( m_bDebug )
			g_Game.AlertMessage( at_logged, "[fall_catch] spawned at %1, dest '%2', watch '%3', fire '%4'\n", pev.origin.ToString(), m_szDest, m_szWatch, m_szFire );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if ( useType == USE_ON )
			m_bEnabled = true;
		else if ( useType == USE_OFF )
			m_bEnabled = false;
		else
			m_bEnabled = !m_bEnabled;
	}

	Vector GetPos( CBaseEntity@ pEnt )
	{
		if ( pEnt.IsBSPModel() )
			return pEnt.Center();
		return pEnt.GetOrigin();
	}

	CBaseEntity@ ResolveDestination()
	{
		if ( m_szDest == "" )
			return null;
		return g_EntityFuncs.FindEntityByTargetname( null, m_szDest );
	}

	void PlayFx( CBasePlayer@ pPlayer )
	{
		g_SoundSystem.EmitSound( pPlayer.edict(), FC_SOUND_CHANNEL, FC_SOUND_FILE, 1.0, ATTN_NORM );
	}

	void Teleport( CBasePlayer@ pPlayer, CBaseEntity@ pFallback )
	{
		CBaseEntity@ pDest = g_EntityFuncs.RandomTargetname( m_szDest );
		if ( pDest is null )
			@pDest = pFallback;

		Vector vecDest = GetPos( pDest );
		vecDest.z += FC_DEST_LIFT - pPlayer.pev.mins.z;

		TraceResult tr;
		for ( int j = 0; j < 4; ++j )
		{
			g_Utility.TraceHull( vecDest, vecDest, dont_ignore_monsters, human_hull, pDest.edict(), tr );
			if ( tr.fAllSolid == 0 && tr.fStartSolid == 0 )
				break;
			vecDest.z += 24.0f;
		}

		if ( m_bDebug )
			g_Game.AlertMessage( at_logged, "[fall_catch] teleport: from %1 to %2 (dest %3)\n", pPlayer.pev.origin.ToString(), vecDest.ToString(), GetPos( pDest ).ToString() );

		g_EntityFuncs.SetOrigin( pPlayer, vecDest );

		if ( ( pev.spawnflags & SF_FC_KEEP_VELOCITY ) == 0 )
			pPlayer.pev.velocity = g_vecZero;

		if ( ( pev.spawnflags & SF_FC_KEEP_ANGLES ) == 0 )
		{
			pPlayer.pev.angles = Vector( 0, pDest.pev.angles.y, 0 );
			pPlayer.pev.fixangle = FAM_FORCEVIEWANGLES;
		}

		PlayFx( pPlayer );
	}

	void Scan()
	{
		bool bUseFire = ( m_szFire != "" );
		bool bDebugTick = m_bDebug && g_Engine.time > m_flNextDebug;
		CBaseEntity@ pDest = ResolveDestination();
		Vector vecRef = self.GetOrigin();

		if ( bDebugTick )
			m_flNextDebug = g_Engine.time + FC_DEBUG_INTERVAL;

		if ( m_szWatch != "" )
		{
			CBaseEntity@ pWatch = g_EntityFuncs.FindEntityByTargetname( null, m_szWatch );
			if ( pWatch is null )
			{
				if ( bDebugTick )
					g_Game.AlertMessage( at_logged, "[fall_catch] watch entity '%1' not found\n", m_szWatch );
				return;
			}
			vecRef = GetPos( pWatch );
		}
		else if ( ( pev.spawnflags & SF_FC_REF_TARGET ) != 0 )
		{
			if ( pDest is null )
			{
				if ( bDebugTick )
					g_Game.AlertMessage( at_logged, "[fall_catch] reference = destination, but '%1' not found\n", m_szDest );
				return;
			}
			vecRef = GetPos( pDest );
		}

		float flLimitZ = vecRef.z + m_flOffset;
		float flRadiusSqr = m_flRadius * m_flRadius;

		float flLowestFeet = 99999.0f;
		int iLowest = 0;

		for ( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

			if ( pPlayer is null || !pPlayer.IsConnected() || !pPlayer.IsAlive() )
				continue;

			float flFeet = pPlayer.pev.origin.z + pPlayer.pev.mins.z;
			if ( flFeet < flLowestFeet )
			{
				flLowestFeet = flFeet;
				iLowest = i;
			}

			if ( g_Engine.time < m_flPlayerNext[i] )
				continue;

			if ( m_flRadius > 0.0f )
			{
				float dx = pPlayer.pev.origin.x - vecRef.x;
				float dy = pPlayer.pev.origin.y - vecRef.y;
				if ( dx * dx + dy * dy > flRadiusSqr )
					continue;
			}

			if ( pPlayer.pev.origin.z + pPlayer.pev.mins.z >= flLimitZ )
				continue;

			if ( m_bDebug )
				g_Game.AlertMessage( at_logged, "[fall_catch] fall: origin %1, ref %2, limit z %3\n", pPlayer.pev.origin.ToString(), vecRef.ToString(), flLimitZ );

			m_flPlayerNext[i] = g_Engine.time + m_flCooldownTime;

			if ( ( pev.spawnflags & SF_FC_KILL ) != 0 )
			{
				pPlayer.Killed( self.pev, GIB_NEVER );
				continue;
			}

			if ( bUseFire )
			{
				g_EntityFuncs.FireTargets( m_szFire, pPlayer, self, USE_TOGGLE, 0.0f );
				PlayFx( pPlayer );
				continue;
			}

			if ( pDest is null )
			{
				if ( m_bDebug )
					g_Game.AlertMessage( at_logged, "[fall_catch] no destination found\n" );
				continue;
			}

			Teleport( pPlayer, pDest );
		}

		if ( bDebugTick )
			g_Game.AlertMessage( at_logged, "[fall_catch] ref %1, limit z %2, lowest player #%3 feet z %4, dest found %5\n", vecRef.ToString(), flLimitZ, iLowest, flLowestFeet, pDest !is null );
	}

	void Think()
	{
		if ( m_bEnabled )
			Scan();
		else if ( m_bDebug && g_Engine.time > m_flNextDebug )
		{
			m_flNextDebug = g_Engine.time + FC_DEBUG_INTERVAL;
			g_Game.AlertMessage( at_logged, "[fall_catch] disabled\n" );
		}

		pev.nextthink = g_Engine.time + FC_THINK_INTERVAL;
	}
}

void MapInit()
{
	g_SoundSystem.PrecacheSound( FC_SOUND_FILE );
	g_CustomEntityFuncs.RegisterCustomEntity( "CFallCatch", "trigger_fall_catch" );
}
