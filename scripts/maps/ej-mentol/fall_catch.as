const int SF_FC_RESPAWN = 1;
const int SF_FC_DEBUG = 2;

const SOUND_CHANNEL FC_SOUND_CHANNEL = CHAN_AUTO;
const float FC_DEBUG_INTERVAL = 5.0f;

class CFallCatch : ScriptBaseEntity
{
	float m_flOffset = -8.0f;
	float m_flRadius = 0.0f;
	float m_flCooldownTime = 0.5f;
	float m_flScanTime = 0.1f;
	array<float> m_flPlayerNext( 33, 0.0f );
	string m_szTarget;
	string m_szWatch;
	string m_szSound;
	float m_flVolume = 10.0f;
	int m_iPitch = 100;
	int m_iInitialState = 1;
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
		else if ( szKey == "cooldown" )
		{
			m_flCooldownTime = atof( szValue );
			return true;
		}
		else if ( szKey == "scantime" )
		{
			m_flScanTime = atof( szValue );
			return true;
		}
		else if ( szKey == "watch" )
		{
			m_szWatch = szValue;
			return true;
		}
		else if ( szKey == "sound" )
		{
			m_szSound = szValue;
			return true;
		}
		else if ( szKey == "pitch" )
		{
			m_iPitch = atoi( szValue );
			return true;
		}
		else if ( szKey == "initial_state" )
		{
			m_iInitialState = atoi( szValue );
			return true;
		}
		return BaseClass.KeyValue( szKey, szValue );
	}

	void Precache()
	{
		BaseClass.Precache();
		if ( m_szSound != "" )
			g_SoundSystem.PrecacheSound( m_szSound );
	}

	void Spawn()
	{
		Precache();

		pev.solid = SOLID_NOT;
		pev.effects = EF_NODRAW;

		if ( m_flScanTime < 0.01f )
			m_flScanTime = 0.1f;
		if ( m_flRadius < 0.0f )
			m_flRadius = 0.0f;
		if ( m_flCooldownTime < 0.0f )
			m_flCooldownTime = 0.0f;
		m_flVolume = pev.health > 0.0f ? pev.health : 10.0f;
		if ( m_flVolume > 10.0f )
			m_flVolume = 10.0f;
		if ( m_iPitch < 1 )
			m_iPitch = 100;
		else if ( m_iPitch > 255 )
			m_iPitch = 255;

		m_szTarget = string( pev.target );
		m_bEnabled = m_iInitialState != 0;
		m_bDebug = ( pev.spawnflags & SF_FC_DEBUG ) != 0;

		SetThink( ThinkFunction( this.Think ) );
		SetUse( UseFunction( this.Use ) );
		pev.nextthink = g_Engine.time + m_flScanTime;

		if ( m_bDebug )
			g_Game.AlertMessage( at_console, "[fall_catch] spawned at %1, watch '%2', target '%3', scantime %4\n", pev.origin.ToString(), m_szWatch, m_szTarget, m_flScanTime );
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

	void PlayFx( CBasePlayer@ pPlayer )
	{
		if ( m_szSound == "" )
			return;

		g_SoundSystem.EmitSoundDyn( pPlayer.edict(), FC_SOUND_CHANNEL, m_szSound, m_flVolume * 0.1f, ATTN_NORM, 0, m_iPitch, pPlayer.entindex() );
	}

	void Scan()
	{
		bool bDebugTick = m_bDebug && g_Engine.time > m_flNextDebug;
		bool bRespawn = ( pev.spawnflags & SF_FC_RESPAWN ) != 0;
		Vector vecRef = self.GetOrigin();

		if ( bDebugTick )
			m_flNextDebug = g_Engine.time + FC_DEBUG_INTERVAL;

		if ( m_szWatch != "" )
		{
			CBaseEntity@ pWatch = g_EntityFuncs.FindEntityByTargetname( null, m_szWatch );
			if ( pWatch is null )
			{
				if ( bDebugTick )
					g_Game.AlertMessage( at_console, "[fall_catch] watch entity '%1' not found\n", m_szWatch );
				return;
			}
			vecRef = GetPos( pWatch );
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

			if ( flFeet >= flLimitZ )
				continue;

			if ( m_bDebug )
				g_Game.AlertMessage( at_console, "[fall_catch] fall: origin %1, ref %2, limit z %3\n", pPlayer.pev.origin.ToString(), vecRef.ToString(), flLimitZ );

			m_flPlayerNext[i] = g_Engine.time + m_flCooldownTime;

			if ( m_szTarget != "" )
				g_EntityFuncs.FireTargets( m_szTarget, pPlayer, self, USE_TOGGLE, 0.0f );

			if ( bRespawn )
				g_PlayerFuncs.RespawnPlayer( pPlayer );

			PlayFx( pPlayer );
		}

		if ( bDebugTick )
			g_Game.AlertMessage( at_console, "[fall_catch] ref %1, limit z %2, lowest player #%3 feet z %4\n", vecRef.ToString(), flLimitZ, iLowest, flLowestFeet );
	}

	void Think()
	{
		if ( m_bEnabled )
			Scan();
		else if ( m_bDebug && g_Engine.time > m_flNextDebug )
		{
			m_flNextDebug = g_Engine.time + FC_DEBUG_INTERVAL;
			g_Game.AlertMessage( at_console, "[fall_catch] disabled\n" );
		}

		pev.nextthink = g_Engine.time + m_flScanTime;
	}
}

void MapInit()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "CFallCatch", "trigger_fall_catch" );
}
