package com.runformcoach.runformcoachai.di

import android.content.Context
import androidx.room.Room
import androidx.room.RoomDatabase
import com.runformcoach.runformcoachai.data.AnalysisDao
import com.runformcoach.runformcoachai.data.FeedbackDao
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
            // RF-921: Enable WAL mode for concurrent reads during cold start.
            // WAL allows reads to proceed while writes are in-flight,
            // reducing UI jank during DB-heavy operations.
            .setJournalMode(RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)
            .fallbackToDestructiveMigration() // acceptable for v1→v2; remove for v3+
            .build()
    }

    @Provides
    fun provideAnalysisDao(db: RunFormDatabase): AnalysisDao = db.analysisDao()

    @Provides
    fun providePlanDao(db: RunFormDatabase): PlanDao = db.planDao()

    @Provides
    fun provideProfileDao(db: RunFormDatabase): ProfileDao = db.profileDao()

    @Provides
    fun provideFeedbackDao(db: RunFormDatabase): FeedbackDao = db.feedbackDao()
}
