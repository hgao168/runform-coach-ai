package com.runformcoach.runformcoachai.di

import android.content.Context
import androidx.room.Room
import com.runformcoach.runformcoachai.data.AnalysisDao
import com.runformcoach.runformcoachai.data.PlanDao
import com.runformcoach.runformcoachai.data.ProfileDao
import com.runformcoach.runformcoachai.data.RunFormDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): RunFormDatabase {
        return Room.databaseBuilder(
            context,
            RunFormDatabase::class.java,
            "runform.db"
        )
            .fallbackToDestructiveMigration() // acceptable for v1; remove for v2+
            .build()
    }

    @Provides
    fun provideAnalysisDao(db: RunFormDatabase): AnalysisDao = db.analysisDao()

    @Provides
    fun providePlanDao(db: RunFormDatabase): PlanDao = db.planDao()

    @Provides
    fun provideProfileDao(db: RunFormDatabase): ProfileDao = db.profileDao()
}
