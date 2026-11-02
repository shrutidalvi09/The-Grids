import { Module } from '@nestjs/common';
import { FacilitiesController } from './facilities/facilities.controller.js';
import { FacilitiesService } from './facilities/facilities.service.js';
import { HomeController } from './home/home.controller.js';
import { HomeService } from './home/home.service.js';
import { ComplaintsController } from './tower/complaints.controller.js';
import { NoticesController } from './tower/notices.controller.js';
import { VehiclesController } from './profile/vehicles.controller.js';
import { DailyHelpController } from './tower/daily-help.controller.js';
import { EventsController } from './tower/events.controller.js';
import { SosController } from './tower/sos.controller.js';
import { ResidentsController } from './tower/residents.controller.js';
import { VisitorPassesController } from './tower/visitor-passes.controller.js';
import { UploadsController } from './uploads/uploads.controller.js';
import { WeatherService } from './weather/weather.service.js';

/** Home and Tower features (Phase 3). */
@Module({
  controllers: [
    HomeController,
    NoticesController,
    ResidentsController,
    VisitorPassesController,
    EventsController,
    DailyHelpController,
    SosController,
    VehiclesController,
    ComplaintsController,
    FacilitiesController,
    UploadsController,
  ],
  providers: [HomeService, FacilitiesService, WeatherService],
})
export class FeaturesModule {}
