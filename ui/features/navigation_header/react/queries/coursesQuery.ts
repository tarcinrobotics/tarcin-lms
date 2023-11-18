/*
 * Copyright (C) 2023 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import $ from 'jquery'
import parseLinkHeader from 'link-header-parsing/parseLinkHeaderFromXHR'
import {savedObservedId} from '@canvas/observer-picker/ObserverGetObservee'
import type {Course} from '../../../../api.d'

const RESOURCE_COUNT = 10

function getFirstPageUrl() {
  const defaultFirstPageUrl =
    '/api/v1/users/self/favorites/courses?include[]=term&exclude[]=enrollments&sort=nickname'

  const isObserver = ENV.current_user_roles.includes('observer')

  // if user is an observer, only retrieve the courses for the observee
  if (isObserver) {
    const observedUserId = savedObservedId(ENV.current_user_id)
    if (observedUserId) {
      return `${defaultFirstPageUrl}&observed_user_id=${observedUserId}`
    }
  }
  return defaultFirstPageUrl
}

const filterCourses = (courses: Course[]): Course[] => {
  return window.ENV.K5_USER &&
    window.ENV.current_user_roles?.every(role => role === 'student' || role === 'user')
    ? courses.filter(c => !c.homeroom_course)
    : courses
}

export default function coursesQuery(): Promise<Course[]> {
  return new Promise((resolve, reject) => {
    const data: Course[] = []

    const firstPageUrl = getFirstPageUrl()

    function load(url: string) {
      $.getJSON(
        url,
        (newData: Course[], _: any, xhr: XMLHttpRequest) => {
          data.push(...newData)
          const link = parseLinkHeader(xhr)
          if (newData.length >= RESOURCE_COUNT && link.next) {
            load(link.next)
          } else {
            resolve(filterCourses(data || []))
          }
        },
        reject
      )
    }
    load(firstPageUrl)
  })
}
